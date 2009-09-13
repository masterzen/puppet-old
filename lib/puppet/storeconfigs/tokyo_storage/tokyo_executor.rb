require 'puppet/storeconfigs/tokyo_storage'

module Puppet::Storeconfigs::TokyoStorage::TokyoExecutor
    def execute
        connection = Puppet::Storeconfigs::TokyoStorage.get_connection
        begin
            return yield connection
        ensure
            Puppet::Storeconfigs::TokyoStorage.close(connection)
        end
    end
    alias :tokyo_execute :execute

    def write
        connection = Puppet::Storeconfigs::TokyoStorage.get_write_connection
        begin
            return yield connection
        ensure
            Puppet::Storeconfigs::TokyoStorage.close(connection)
        end
    end
end