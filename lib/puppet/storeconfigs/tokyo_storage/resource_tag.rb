require 'puppet/storeconfigs/tokyo_storage'
require 'puppet/storeconfigs/tokyo_storage/tokyo_object'
require 'puppet/storeconfigs/tokyo_storage/tokyo_executor'

class Puppet::Storeconfigs::TokyoStorage::ResourceTag
    include Puppet::Storeconfigs::TokyoStorage::TokyoExecutor
    include Puppet::Storeconfigs::TokyoStorage::TokyoObject
    extend Puppet::Storeconfigs::TokyoStorage::TokyoObject::ClassMethods

    def self.prefix
        "tag"
    end

end