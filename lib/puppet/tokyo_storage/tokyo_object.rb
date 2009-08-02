require 'puppet/tokyo_storage'
require 'puppet/tokyo_storage/tokyo_executor'

module Puppet::TokyoStorage::TokyoObject
    include Puppet::TokyoStorage::TokyoExecutor

    attr_accessor :values

    def initialize(hash={})
        puts "creating: %s with: %s" % [self.class, hash.inspect]
        @values = hash || {}
        unless hash.include?(:pk) or hash.include?("pk")
            @values[:pk] = id
        end
    end

    def []=(name, value)
        @values[name] = value
    end

    def [](value)
        puts "[]: %s %s == %s" % [self.class, value, @values[value]]
        @values[value]
    end

    def id
        self[:pk] || self.class.gen_pk
    end

    def save
        local_id = id
        write do |tokyo|
            tokyo[local_id] = values.reject { |n,v| n == :pk }
        end
    end

    module ClassMethods
        include Puppet::TokyoStorage::TokyoExecutor

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
                    q.add_condition :pk, :starts_with, prefix
                end
                puts "hash: %s" % hash.inspect
                return self.new(hash.shift) if hash.size > 0
                puts "nil"
                return nil
            end
        end

        def find_by_host(id)
            execute do |tokyo|
                tokyo.query do |q|
                    q.add_condition 'host_id', :equals, id
                    q.add_condition :pk, :starts_with, prefix
                end
            end
        end

        def destroy(objects)
            write do |tokyo|
                objects.each do |o|
                    tokyo.query_delete do |q|
                        q.add_condition 'pk', :equals, o.id
                    end
                end
            end
        end

        def create(hash)
            write do |tokyo|
                tokyo[gen_pk_from_id(tokyo.generate_unique_id)] = hash.reject { |n,v| n == :pk }
            end
        end
    end

    extend ClassMethods
end