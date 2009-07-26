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

    def save
        execute do |tokyo|
            tokyo[id] = values
        end
    end
end