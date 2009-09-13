require 'puppet/storeconfigs/tokyo_storage'
require 'puppet/storeconfigs/tokyo_storage/tokyo_executor'
require 'puppet/storeconfigs/tokyo_storage/tokyo_object'

class Puppet::Storeconfigs::TokyoStorage::Index
    extend Puppet::Storeconfigs::TokyoStorage::TokyoExecutor

    INDEX = [
        { :name => :pk , :type => :lexical },
        { :name => "name" , :type => :lexical },
        { :name => "host_id" , :type => :decimal },
        { :name => "title" , :type => :lexical },
        { :name => "type" , :type => :lexical },
        { :name => "resource_id" , :type => :lexical },
    ];

    # add indices if not present
    def self.build
        write do |tokyo|
            INDEX.each do |index|
                unless tokyo.set_index(index[:name], index[:type], :keep)
                    tokyo.set_index(index[:name], index[:type])
                end
            end
        end
    end

end