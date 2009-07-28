require 'puppet/tokyo_storage/host'
require 'puppet/indirector/active_record'
require 'puppet/node'

class Puppet::Node::TokyoStorage < Puppet::Indirector::TokyoStorage
    use_ar_model Puppet::TokyoStorage::Host
end
