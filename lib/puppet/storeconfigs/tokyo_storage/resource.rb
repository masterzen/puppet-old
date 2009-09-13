require 'puppet/storeconfigs/tokyo_storage'
require 'puppet/storeconfigs/tokyo_storage/tokyo_executor'
require 'puppet/storeconfigs/tokyo_storage/tokyo_object'

class Puppet::Storeconfigs::TokyoStorage::Resource
    include Puppet::Storeconfigs::TokyoStorage::TokyoExecutor
    include Puppet::Storeconfigs::TokyoStorage::TokyoObject
    extend Puppet::Storeconfigs::TokyoStorage::TokyoObject::ClassMethods

    include Puppet::Util::CollectionMerger
    include Puppet::Util::ReferenceSerializer
    include Puppet::Util::Rails::Benchmark

    def add_param_to_hash(param)
        @params_hash ||= []
        @params_hash << param
    end

    def add_tag_to_hash(tag)
        @tags_hash ||= []
        @tags_hash << tag
    end

    def params_hash=(hash)
        @params_hash = hash
    end

    def tags_hash=(hash)
        @tags_hash = hash
    end

    def ref
        "%s[%s]" % [values["type"].split("::").collect { |s| s.capitalize }.join("::"), values["title"]]
    end

    # Determine the basic details on the resource.
    def self.resource_initial_args(host_id, resource)
        result = [:type, :title, :line].inject({}) do |hash, param|
            if value = resource.send(param)
                hash[param] = value
            end
            hash
        end

        # We always want a value here, regardless of what the resource has,
        # so we break it out separately.
        result[:exported] = resource.exported || false
        result[:host_id] = host_id

        result
    end

    # Make sure this resource is equivalent to the provided Parser resource.
    def merge_parser_resource(resource)
        accumulate_benchmark("Individual resource merger", :attributes) { merge_attributes(resource) }
        accumulate_benchmark("Individual resource merger", :parameters) { merge_parameters(resource) }
        accumulate_benchmark("Individual resource merger", :tags) { merge_tags(resource) }
        save()
    end

    def merge_attributes(resource)
        args = self.class.resource_initial_args(self[:host_id], resource)
        args.each do |param, value|
            unless resource[param] == value
                self[param] = value
            end
        end
    end

    def merge_parameters(resource)
        catalog_params = {}
        resource.each do |param, value|
            catalog_params[param.to_s] = value
        end

        db_params = {}

        deletions = []
        @params_hash.each do |value|
            # First remove any parameters our catalog resource doesn't have at all.
            deletions << value.id and next unless catalog_params.include?(value['name'])

            # Now store them for later testing.
            db_params[value['name']] ||= []
            db_params[value['name']] << value
        end

        # Now get rid of any parameters whose value list is different.
        # This might be extra work in cases where an array has added or lost
        # a single value, but in the most common case (a single value has changed)
        # this makes sense.
        db_params.each do |name, value_hashes|
            values = value_hashes.collect { |v| v['value'] }

            unless value_compare(catalog_params[name], values)
                value_hashes.each { |v| deletions << v.id }
            end
        end

        # Perform our deletions.
        Puppet::Storeconfigs::TokyoStorage::ResourceParameter.destroy(deletions) unless deletions.empty?

        # Lastly, add any new parameters.
        catalog_params.each do |name, value|
            next if db_params.include?(name)
            values = value.is_a?(Array) ? value : [value]

            values.each do |v|
                Puppet::Storeconfigs::TokyoStorage::ResourceParameter.create(
                    :value => serialize_value(v),
                    :line => resource.line,
                    :name => name,
                    :resource_id => self.id,
                    :host_id => self[:host_id])
            end
        end
    end

    # Make sure the tag list is correct.
    def merge_tags(resource)
        in_db = []
        deletions = []
        resource_tags = resource.tags
        @tags_hash.each do |tag|
            deletions << tag[:pk] and next unless resource_tags.include?(tag['tag'])
            in_db << tag['tag']
        end
        Puppet::Storeconfigs::TokyoStorage::ResourceTag.destroy(deletions) unless deletions.empty?

        (resource_tags - in_db).each do |tag|
            self.class.add_resource_tag(self[:host_id], self.id , tag)
        end
    end

    def self.add_resource_tag(host_id, resource_id, tag)
        Puppet::Storeconfigs::TokyoStorage::ResourceTag.create(:tag => tag, :resource_id => resource_id, :host_id => host_id)
    end

    def value_compare(v,db_value)
        v = [v] unless v.is_a?(Array)
        v == db_value
    end

end