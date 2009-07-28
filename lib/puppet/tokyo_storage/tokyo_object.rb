require 'puppet/tokyo_storage'

module Puppet::TokyoStorage::TokyoObject
    include Executor

    attr_accessor :values, :id

    def initialize(hash={})
        values = hash
    end

    def []=(name, value)
        values[name] = value
    end

    def [](value)
        values[value]
    end

    def self.prefix
        "#{class.to_s.downcase.split('::').pop}"
    end

    # generate a new pk in the form of class_<uniqueid>
    def gen_pk
        execute do |tokyo|
            "#{self.class.prefix}_#{tokyo.generate_unique_id}"
        end
    end

    def save
        execute do |tokyo|
            tokyo[id] = values
        end
    end

    def self.find_by_name(name)
        execute do |tokyo|
            self.class.new(
                tokyo.query do |q|
                    q.add_condition 'name', :equals, name
                    q.add_condition 'pk', :starts_with prefix
                end
            )
        end
    end
end