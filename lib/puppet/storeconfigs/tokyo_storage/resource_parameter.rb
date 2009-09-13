require 'puppet/storeconfigs/tokyo_storage'
require 'puppet/storeconfigs/tokyo_storage/tokyo_object'
require 'puppet/storeconfigs/tokyo_storage/tokyo_executor'

class Puppet::Storeconfigs::TokyoStorage::ResourceParameter
    include Puppet::Storeconfigs::TokyoStorage::TokyoExecutor
    include Puppet::Storeconfigs::TokyoStorage::TokyoObject
    extend Puppet::Storeconfigs::TokyoStorage::TokyoObject::ClassMethods
    include Puppet::Util::ReferenceSerializer
    extend Puppet::Util::ReferenceSerializer

    def self.prefix
        "parameter"
    end

    # Store a new parameter in a Rails db.
    def self.from_parser_param(param, values)
        values = munge_parser_values(values)

        return values.collect do |v|
            {:value => serialize_value(v), :name => param.to_s}
        end
    end

    def self.munge_parser_values(value)
        values = value.is_a?(Array) ? value : [value]
        values = values.collect do |v|
            if v.is_a?(Puppet::Resource::Reference)
                serialize_value(v)
            else
                v.to_s
            end
        end
        values
    end
end