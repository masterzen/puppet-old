require 'puppet/tokyo_storage'
require 'puppet/tokyo_storage/tokyo_object'
require 'puppet/tokyo_storage/tokyo_executor'

class Puppet::TokyoStorage::ResourceParameter
    include Puppet::TokyoStorage::TokyoExecutor
    include Puppet::TokyoStorage::TokyoObject
    extend Puppet::TokyoStorage::TokyoObject::ClassMethods

    def self.prefix
        "parameter_"
    end

    # Store a new parameter in a Rails db.
    def self.from_parser_param(param, values)
        values = munge_parser_values(values)

        return values.collect do |v|
            {:value => v, :name => param.to_s}
        end
    end

    def self.munge_parser_values(value)
        values = value.is_a?(Array) ? value : [value]
        values.map do |v|
            if v.is_a?(Puppet::Resource::Reference)
                v
            else
                v.to_s
            end
        end
    end
end