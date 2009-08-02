require 'puppet/util/feature'

Puppet.features.rubygems?

Puppet.features.add(:tokyo_storage) do
    begin
        require 'rufus/tokyo'
    rescue
        require 'rubygems'
        require 'rufus/tokyo'
    end

    if defined? Rufus::Tokyo::VERSION
        true
    else
        false
    end
end
