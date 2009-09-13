require 'puppet/storeconfigs/tokyo_storage/host'
require 'puppet/indirector/storeconfigs'
require 'puppet/node'

class Puppet::Node::TokyoStorage < Puppet::Indirector::Storeconfigs
    use_ar_model Puppet::Storeconfigs::TokyoStorage::Host

    def find(request)
        node = super
        node.fact_merge
        node
    end
end
