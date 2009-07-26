require 'puppet/tokyo_storage/executor'
require 'puppet/tokyo_storage/tokyo_object'

class Puppet::TokyoStorage::Host
    include TokyoExecutor
    include TokyoObject

    def self.to_hash(node)
        { :name => node.name, :ip => node.ipaddress, :environment => node.environment }
    end

    # If the host already exists, get rid of its objects
    def self.clean(host)
    end

    def self.find_by_name(conenction, name)
        class.new(connection.query { |q|
          q.add_condition 'name', :equals, name
        })
    end

    def self.from_puppet(node)
        tokyo = Puppet::TokyoStorage.gethandle
        begin
            host = find_by_name(node.name) || class.new(to_hash(node))

            host[:ip] = node.ipaddress
            host[:environment] = node.environment

            host
        ensure
            Puppet::TokyoStorage.close_handle(connection)
        end
    end

    def to_puppet
        node = Puppet::Node.new(self.name)
        values.each do |n,v|
            node.send(n+"=", v)
        end

        node
    end

    # Set our resources.
    def merge_resources(list)
        # keep only exported resources in thin_storeconfig mode
        list = list.select { |r| r.exported? } if Puppet.settings[:thin_storeconfigs]

        resources_by_id = nil
        debug_benchmark("Searched for resources") {
            resources_by_id = find_resources()
        }

        debug_benchmark("Searched for resource params and tags") {
            find_resources_parameters_tags(resources_by_id)
        } if id

        debug_benchmark("Performed resource comparison") {
            compare_to_catalog(resources_by_id, list)
        }
    end

    def find_resources
        Puppet::TokyoStorage::Resources.find_by_host(self[:id]).inject({}) do | hash, resource |
            hash[resource.id] = resource
            hash
        end
    end

    def find_resources_parameters_tags(resources)
        # initialize all resource parameters
        resources.each do |key,resource|
            resource.params_hash = []
        end

        find_resources_parameters(resources)
        find_resources_tags(resources)
    end

    def compare_to_catalog(existing, list)
        compiled = list.inject({}) do |hash, resource|
            hash[resource.ref] = resource
            hash
        end

        resources = nil
        debug_benchmark("Resource removal") {
            resources = remove_unneeded_resources(compiled, existing)
        }

        # Now for all resources in the catalog but not in the db, we're pretty easy.
        additions = nil
        debug_benchmark("Resource merger") {
            additions = perform_resource_merger(compiled, resources)
        }

        debug_benchmark("Resource addition") {
            additions.each do |resource|
                build_rails_resource_from_parser_resource(resource)
            end

            log_accumulated_marks "Added resources"
        }
    end

    def add_new_resources(additions)
        additions.each do |resource|
            Puppet::TokyoStorage::Resource.from_parser_resource(self, resource)
        end
    end

    # Turn a parser resource into a Rails resource.
    def build_rails_resource_from_parser_resource(resource)
        db_resource = nil
        accumulate_benchmark("Added resources", :initialization) {
            args = Puppet::TokyoStorage::Resource.resource_initial_args(resource)

            db_resource = self.resources.build(args)

            # Our file= method does the name to id conversion.
            db_resource.file = resource.file
        }


        accumulate_benchmark("Added resources", :parameters) {
            resource.each do |param, value|
                Puppet::Rails::ParamValue.from_parser_param(param, value).each do |value_hash|
                    db_resource.param_values.build(value_hash)
                end
            end
        }

        accumulate_benchmark("Added resources", :tags) {
            resource.tags.each { |tag| db_resource.add_resource_tag(tag) }
        }

        db_resource.save

        return db_resource
    end

end