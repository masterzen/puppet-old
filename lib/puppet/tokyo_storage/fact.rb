require 'puppet/tokyo_storage'
require 'puppet/tokyo_storage/tokyo_object'
require 'puppet/tokyo_storage/tokyo_executor'

class Puppet::TokyoStorage::Fact
    include Puppet::TokyoStorage::TokyoExecutor
    include Puppet::TokyoStorage::TokyoObject
    extend Puppet::TokyoStorage::TokyoObject::ClassMethods

end