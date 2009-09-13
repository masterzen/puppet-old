require 'puppet/util'
require 'puppet/storeconfigs/tokyo_storage'
require 'puppet/storeconfigs/tokyo_storage/tokyo_executor'

module Puppet::Storeconfigs::TokyoStorage::TokyoObject
    include Puppet::Storeconfigs::TokyoStorage::TokyoExecutor
    include Puppet::Util
    include Puppet::Util::ReferenceSerializer

    attr_accessor :values

    def initialize(hash={})
        @values = hash || {}

        @values = @values.inject({}) do |h,v|
            h[v[0]] = serialize_value(v[1])
            h
        end

        unless hash.include?(:pk) or hash.include?("pk")
            @values[:pk] = id
        end
    end

    def []=(name, value)
        @values[name.to_s] = value
    end

    def [](name)
        @values[name.to_s]
    end

    def id
        @values[:pk] || self.class.gen_pk
    end

    def method_missing(m,*args)
        if m =~ /=$/ # setter
            self[m] = *args
        else
            self[m]
        end
    end

    def save
        local_id = id
        write do |tokyo|
            tokyo[local_id] = values.reject { |n,v| n == :pk }
        end
    end

    module ClassMethods
        include Puppet::Storeconfigs::TokyoStorage::TokyoExecutor

        # generate a new pk in the form of class_<uniqueid>
        def gen_pk
            write do |tokyo|
                "#{prefix}_#{tokyo.generate_unique_id}"
            end
        end

        def gen_pk_from_id(id)
            "#{prefix}_#{id}"
        end

        def prefix
            self.to_s.downcase.split('::').pop
        end

        def find_by_name(name)
            execute do |tokyo|
                hash = tokyo.query do |q|
                    q.add_condition 'name', :equals, name
                    q.add_condition '', :starts_with, prefix
                end
                return self.new(hash.shift) if hash.size > 0
                return nil
            end
        end

        def find_by_host(id)
            execute do |tokyo|
                tokyo.query do |q|
                    q.add_condition 'host_id', :equals, id
                    q.add_condition '', :starts_with, prefix
                end.collect do |o|
                    self.new(o)
                end
            end
        end

        def find_as_hash(id)
            execute do |tokyo|
                tokyo.query do |q|
                    q.add_condition 'host_id', :equals, id
                    q.add_condition '', :starts_with, prefix
                end
            end
        end

        def destroy(objects)
            puts "obj: %s" % objects.inspect
            write do |tokyo|
                objects.each do |o|
                    tokyo.delete o
                end
            end
        end

        def create(hash)
            a = nil
            hash = hash.inject({}) do |h,v|
                h[v[0].to_s] = v[1]
                h
            end
            write do |tokyo|
                a = gen_pk_from_id(tokyo.generate_unique_id)
                tokyo[a] = hash.reject { |n,v| n == :pk }
            end
            return self.new(hash.merge( :pk => a ))
        end
    end

    extend ClassMethods
end