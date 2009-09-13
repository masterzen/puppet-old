require 'puppet'
require 'rufus/tokyo'
require 'rufus/tokyo/cabinet/table'
require 'rufus/tokyo/tyrant'

module Puppet::Storeconfigs::TokyoStorage
    TIME_DEBUG = true

    def self.get_connection
        # does the current thread has already a connection?
        unless connection = Thread.current[:tokyo_connection]
            case Puppet[:tkadapter]
            when "cabinet"
                raise ArgumentError, "Tokyo Cabinet filename must end with \".tct\"" unless Puppet[:tklocation] =~ /\.tct$/
                unless FileTest.exists?(Puppet[:tklocation])
                    Rufus::Tokyo::Table.new(Puppet[:tklocation]+"#mode=wc" + Puppet[:tkoption]).close
                end
                connection = Rufus::Tokyo::Table.new(Puppet[:tklocation]+"#mode=r" + Puppet[:tkoption])
            when "tyrant"
                connection = Rufus::Tokyo::Tyrant.new(Puppet[:tkserver], Puppet[:tkport])
            end
            Thread.current[:tokyo_connection] = connection
        end
        connection
    end

    def self.get_write_connection
        # does the current thread has already a connection?
        unless connection = Thread.current[:tokyo_connection]
            case Puppet[:tkadapter]
            when "cabinet"
                raise ArgumentError, "Tokyo Cabinet filename must end with \".tct\"" unless Puppet[:tklocation] =~ /\.tct$/
                connection = Rufus::Tokyo::Table.new(Puppet[:tklocation]+"#mode=wc" + Puppet[:tkoption] )
            when "tyrant"
                connection = Rufus::Tokyo::Tyrant.new(Puppet[:tkserver], Puppet[:tkport])
            end
            Thread.current[:tokyo_connection] = connection
        end
        connection
    end

    def self.close(connection)
        if Thread.current[:tokyo_connection].nil?
            raise Puppet::DevError, "Thread is trying to checkin a connection in an empty slot"
        end
        Thread.current[:tokyo_connection] = nil
        connection.close
    end

    def self.init
        unless Puppet.features.tokyo_storage?
            raise Puppet::DevError, "No Tokyo Cabinet or Tokyo Tyrant, cannot init Puppet::Storeconfigs::TokyoStorage"
        end

        Puppet.settings.use(:main, :tokyo_storage, :puppetmasterd)

        require 'puppet/storeconfigs/tokyo_storage/index'
        Puppet::Storeconfigs::TokyoStorage::Index.build
    end
end

if Puppet.features.tokyo_storage?
    require 'puppet/storeconfigs/tokyo_storage/host'
end

