require 'puppet/tokyo_storage'

module Puppet::TokyoStorage::Executor
    def execute
        connection = Puppet::TokyoStorage.gethandle
        begin
            yield
        ensure
            Puppet::TokyoStorage.closehandle(connection)
        end
    end
end