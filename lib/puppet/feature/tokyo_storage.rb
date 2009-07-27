require 'puppet/util/feature'

Puppet.features.rubygems?

Puppet.features.add(:tokyo_storage) do
    begin
        require 'rufus/tokyo'
    rescue LoadError => detail
    end

    return true if defined? ::Rufus::Tokyo::Cabinet
    return false
end
