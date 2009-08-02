require 'puppet'

class Puppet::Storeconfigs

    def self.get_class
        case Puppet[:storeconfigs_source]
        when "rails"
            return Puppet::Rails
        when "tokyo_storage"
            return Puppet::TokyoStorage
        end
    end

    class << self
        [:init, :teardown, :migrate].each do |m|
            define_method(m) do
                get_class.send(m)
            end
        end
    end
end