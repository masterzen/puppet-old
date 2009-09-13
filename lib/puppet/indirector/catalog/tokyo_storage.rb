require 'puppet/storeconfigs/tokyo_storage/host'
require 'puppet/indirector/storeconfigs'
require 'puppet/resource/catalog'

class Puppet::Resource::Catalog::TokyoStorage < Puppet::Indirector::Storeconfigs
    use_ar_model Puppet::Storeconfigs::TokyoStorage::Host

    # If we can find the host, then return a catalog with the host's resources
    # as the vertices.
    def find(request)
        return nil unless request.options[:cache_integration_hack]
        return nil unless host = ar_model.find_by_name(request.key)

        catalog = Puppet::Resource::Catalog.new(host.name)

        host.resources.each do |resource|
             catalog.add_resource resource.to_transportable
        end

        catalog
    end

    # Save the values from a Facts instance as the facts on a Rails Host instance.
    def save(request)
        catalog = request.instance

        host = ar_model.find_by_name(catalog.name) || ar_model.new(:name => catalog.name)

        host.merge_resources(catalog.vertices)
        host[:last_compile] = Time.now

        host.save
    end
end
