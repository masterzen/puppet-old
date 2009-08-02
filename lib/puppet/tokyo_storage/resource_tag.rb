require 'puppet/tokyo_storage'
require 'puppet/tokyo_storage/tokyo_object'
require 'puppet/tokyo_storage/tokyo_executor'

class Puppet::TokyoStorage::ResourceTag
    include Puppet::TokyoStorage::TokyoExecutor
    include Puppet::TokyoStorage::TokyoObject
    extend Puppet::TokyoStorage::TokyoObject::ClassMethods

    def self.prefix
        "tag_"
    end

end