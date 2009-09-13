
class Puppet::Storeconfigs
    class << self
        attr_reader :source, :source_name

        def source=(type)
            @source_name = type
            @source = Puppet::Storeconfigs.const_get(name2const(type))
        end

        [:init, :teardown, :migrate].each do |m|
            define_method(m) do
                if Puppet.features.send("#{source_name}?")
                    source.send(m)
                else
                    raise Puppet::Error, "#{source_name} is missing; cannot store configurations"
                end
            end
        end

        # Convert a short name to a constant.
        def name2const(name)
            name.to_s.capitalize.gsub(/_(.)/) { |i| $1.upcase }
        end
    end
end