require 'puppet/tokyo_storage'
require 'puppet/tokyo_storage/tokyo_object'
require 'puppet/tokyo_storage/tokyo_executor'

class Puppet::TokyoStorage::ResourceParameter
    include Puppet::TokyoStorage::TokyoExecutor
    include Puppet::TokyoStorage::TokyoObject
    extend Puppet::TokyoStorage::TokyoObject::ClassMethods
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
            puts "munge: %s" % v.inspect
            if v.is_a?(Puppet::Resource::Reference)
                puts "ser: %s" % serialize_value(v).inspect
                serialize_value(v)
            else
                puts "to_s: %s" % v.inspect
                v.to_s
            end
        end
        puts "munged values: %s" % values.inspect
        values
    end
end