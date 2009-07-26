# Load the appropriate libraries, or set a class indicating they aren't available

require 'facter'
require 'puppet'
require 'rufus/tokyo'

module Puppet::TokyoStorage
    TIME_DEBUG = true

    def self.gethandle
        # does the current thread has already a connection?
        unless connection = Thread.current[:tokyo_connection]
            case Puppet[:dbadapter]
            when "cabinet"
                connection = Rufus::Tokyo::Cabinet.new(Puppet[:dblocation] + Puppet[:dboption])
            when "tyrant"
                connection = Rufus::Tokyo::Tyrant.new(Puppet[:dbserver], Puppet[:dbport])
            end
        end
        connection
    end

    def self.closehandle(connection)
        unless Thread.current[:tokyo_connection] == connection
            raise Puppet::DevError, "Thread is trying to checkin a connection in an empty slot"
        end
        Thread.current[:tokyo_connection] = nil
        connection.close
    end

    # Set up our database connection.  It'd be nice to have a "use" system
    # that could make callbacks.
    def self.init
        unless Puppet.features.tokyo_storage?
            raise Puppet::DevError, "No Tokyo Cabinet or Tokyo Tyrant, cannot init Puppet::TokyoStorage"
        end

        connect()
    end
end