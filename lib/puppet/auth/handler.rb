
module Puppet::Auth::Handler
  def self.included(mod)
    type = mod.name.sub(/Puppet::Network::HTTP::(.*)REST/, '\1').downcase
    mod.send(:include, Puppet::Auth::handler(type))
  end
end