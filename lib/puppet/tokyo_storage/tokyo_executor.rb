require 'puppet/tokyo_storage'

module Puppet::TokyoStorage::TokyoExecutor
    def execute
        connection = Puppet::TokyoStorage.get_connection
        begin
            return yield connection
        ensure
            Puppet::TokyoStorage.close(connection)
        end
    end
    alias :tokyo_execute :execute

    def write
        connection = Puppet::TokyoStorage.get_write_connection
        begin
            return yield connection
        ensure
            Puppet::TokyoStorage.close(connection)
        end
    end
end