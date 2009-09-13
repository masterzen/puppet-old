require 'puppet/storeconfigs/tokyo_storage'
require 'puppet/storeconfigs/tokyo_storage/tokyo_executor'
require 'puppet/storeconfigs/tokyo_storage/tokyo_object'
require 'puppet/storeconfigs/tokyo_storage/resource'
require 'puppet/storeconfigs/tokyo_storage/resource_parameter'
require 'puppet/storeconfigs/tokyo_storage/resource_tag'
require 'puppet/storeconfigs/tokyo_storage/fact'

class Puppet::Storeconfigs::TokyoStorage::Host
    extend Puppet::Storeconfigs::TokyoStorage::TokyoExecutor
    include Puppet::Storeconfigs::TokyoStorage::TokyoExecutor

    extend Puppet::Storeconfigs::TokyoStorage::TokyoObject::ClassMethods
    include Puppet::Storeconfigs::TokyoStorage::TokyoObject

    include Puppet::Util::Rails::Benchmark
    extend Puppet::Util::Rails::Benchmark
    include Puppet::Util
    include Puppet::Util::CollectionMerger

    def self.to_hash(node)
        { :name => node.name, :ip => node.ipaddress, :environment => node.environment }
    end

    def self.from_puppet(node)
        host = find_by_name(node.name) || self.new(to_hash(node))

        host[:ip] = node.ipaddress
        host[:environment] = node.environment

        host
    end

    def to_puppet
        node = Puppet::Node.new(self.name)
        values.each do |n,v|
            node.send(n+"=", v) unless n == :pk
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

    def resources
        Puppet::Storeconfigs::TokyoStorage::Resource.find_by_host(id)
    end

    def find_resources
        Puppet::Storeconfigs::TokyoStorage::Resource.find_by_host(id).inject({}) do | hash, resource |
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
                build_tokyo_resource_from_parser_resource(resource)
            end

            log_accumulated_marks "Added resources"
        }
    end

    def remove_unneeded_resources(compiled, existing)
        deletions = []
        resources = {}
        existing.each do |id, resource|
            # it seems that it can happen (see bug #2010) some resources are duplicated in the
            # database (ie logically corrupted database), in which case we remove the extraneous
            # entries.
            if resources.include?(resource.ref)
                deletions << id
                next
            end

            # If the resource is in the db but not in the catalog, mark it
            # for removal.
            unless compiled.include?(resource.ref)
                deletions << id
                next
            end

            resources[resource.ref] = resource
        end
        # We need to use 'destroy' here, not 'delete', so that all
        # dependent objects get removed, too.
        Puppet::Storeconfigs::TokyoStorage::Resource.destroy(deletions) unless deletions.empty?

        return resources
    end

    def perform_resource_merger(compiled, resources)
        return compiled.values if resources.empty?

        # Now for all resources in the catalog but not in the db, we're pretty easy.
        additions = []
        compiled.each do |ref, resource|
            if db_resource = resources[ref]
                db_resource.merge_parser_resource(resource)
            else
                additions << resource
            end
        end
        log_accumulated_marks "Resource merger"

        return additions
    end

    # Turn a parser resource into a Rails resource.
    def build_tokyo_resource_from_parser_resource(resource)
        db_resource = nil
        accumulate_benchmark("Added resources", :initialization) {
            args = Puppet::Storeconfigs::TokyoStorage::Resource.resource_initial_args(id, resource)

            db_resource = Puppet::Storeconfigs::TokyoStorage::Resource.create(args)
        }


        accumulate_benchmark("Added resources", :parameters) {
            resource.each do |param, value|
                Puppet::Storeconfigs::TokyoStorage::ResourceParameter.from_parser_param(param, value).each do |value_hash|
                    puts "values_hash: %s" % value_hash.inspect
                    Puppet::Storeconfigs::TokyoStorage::ResourceParameter.create(value_hash.merge(:host_id => self.id, :resource_id => db_resource.id))
                end
            end
        }

        accumulate_benchmark("Added resources", :tags) {
            resource.tags.each { |tag| Puppet::Storeconfigs::TokyoStorage::Resource.add_resource_tag(self.id, db_resource.id, tag) }
        }

        db_resource.save

        return db_resource
    end

    def find_resources_parameters(resources)
        params = Puppet::Storeconfigs::TokyoStorage::ResourceParameter.find_as_hash(self.id)

        # assign each loaded parameters/tags to the resource it belongs to
        params.each do |param|
            resources[param['resource_id']].add_param_to_hash(param) if resources.include?(param['resource_id'])
        end
    end

    def find_resources_tags(resources)
        tags = Puppet::Storeconfigs::TokyoStorage::ResourceTag.find_as_hash(self.id)

        tags.each do |tag|
            resources[tag['resource_id']].add_tag_to_hash(tag) if resources.include?(tag['resource_id'])
        end
    end

    # returns a hash of fact_names.name => [ fact_values ] for this host.
    # Note that 'fact_values' is actually a list of the value instances, not
    # just actual values.
    def get_facts_hash
        fact_values = Puppet::Storeconfigs::TokyoStorage::Fact.find_by_host(id)
        return fact_values.inject({}) do | hash, value |
            hash[value['name']] ||= []
            hash[value['name']] << value
            hash
        end
    end

    # This is *very* similar to the merge_parameters method
    # of Puppet::Storeconfigs::TokyoStorage::Resource.
    def merge_facts(facts)
        db_facts = {}

        deletions = []
        Puppet::Storeconfigs::TokyoStorage::Fact.find_by_host(id).each do |value|
            deletions << value.id and next unless facts.include?(value['name'])
            # Now store them for later testing.
            db_facts[value['name']] ||= []
            db_facts[value['name']] << value
        end

        # Now get rid of any parameters whose value list is different.
        # This might be extra work in cases where an array has added or lost
        # a single value, but in the most common case (a single value has changed)
        # this makes sense.
        db_facts.each do |name, value_hashes|
            values = value_hashes.collect { |v| v['value'] }
            values = values.shift if values.size == 1
            unless values == facts[name]
                puts "NOT MATCHING: %s" % name
                value_hashes.each { |v| deletions << v.id }
            end
        end

        # Perform our deletions.
        Puppet::Storeconfigs::TokyoStorage::Fact.destroy(deletions) unless deletions.empty?

        # Lastly, add any new parameters.
        facts.each do |name, value|
            next if db_facts.include?(name)
            values = value.is_a?(Array) ? value : [value]

            values.each do |v|
                Puppet::Storeconfigs::TokyoStorage::Fact.create(:value => v, :name => name, :host_id => self.id)
            end
        end
    end

end