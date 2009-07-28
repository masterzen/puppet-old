require 'puppet/tokyostorage'


class Puppet::TokyoStorage::Resource
    include TokyoExecutor
    include TokyoObject

    def self.build_index
        execute do |tokyo|
            tokyo.set_index("host_id", :decimal)
            tokyo.set_index(:pk, :decimal)
        end
    end

    def self.to_hash(node)
        { :name => node.name, :ip => node.ipaddress, :environment => node.environment }
    end

    def self.find_by_host(id)
        execute do |tokyo|
            tokyo.query do |q|
                q.add_condition 'host_id', :equals, id
            end
        end
    end
end