require 'puppet/util/feature'

# We want this to load if possible, but it's not automatically
# required.
Puppet.features.rubygems?
Puppet.features.add(:yajl) do
    found = false
    begin
        require 'rubygems'
        require 'yajl'

        #Yajl::Encoder.enable_json_gem_compatability

        class ::Object
            def to_pson(*args, &block)
                "\"#{to_s}\""
            end
        end

        found = true
    rescue LoadError => detail
    end
    found
end
