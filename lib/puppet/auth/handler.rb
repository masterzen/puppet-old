require 'resolv'

module Puppet::Auth::Handler
  def self.included(mod)
    type = mod.name.sub(/Puppet::Network::HTTP::(.*)REST/, '\1').downcase
    mod.send(:include, Puppet::Auth::handler(type))
  end

  # resolve node name from peer's ip address
  # this is used when the request is unauthenticated
  def resolve_node(ip)
    begin
      return Resolv.getname(ip)
    rescue => detail
      Puppet.err "Could not resolve #{ip}: #{detail}"
    end
    ip
  end
end