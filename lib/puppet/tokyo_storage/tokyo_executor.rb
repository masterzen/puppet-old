require 'puppet/tokyo_storage'

module Puppet::TokyoStorage::Executor
    def execute
        connection = Puppet::TokyoStorage.get_connection
        begin
            return yield connection
        ensure
            Puppet::TokyoStorage.close(connection)
        end
    end
end