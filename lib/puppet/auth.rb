require 'puppet/util/instance_loader'
require 'puppet/util/classgen'

class Puppet::Auth
  extend Puppet::Util::ClassGen
  extend Puppet::Util::InstanceLoader

  # One for the clients
  instance_load :client_auth, 'puppet/auth/client'

  # One for the servers
  instance_load :server_auth, 'puppet/auth/server'

  # And one to rule them all
  instance_load :handler_webrick_auth, 'puppet/auth/handler/webrick'
  instance_load :handler_mongrel_auth, 'puppet/auth/handler/mongrel'
  instance_load :handler_rack_auth, 'puppet/auth/handler/rack'

  # Add a new auth type.
  def self.new_client(name, options = {}, &block)
    name = symbolize(name)
    genclass(name, :parent => Puppet::Auth::Client, :prefix => "Client",:hash => instance_hash(:client_auth), :block => block)
  end

  def self.new_server(name, options = {}, &block)
    name = symbolize(name)
    genclass(name, :parent => Puppet::Auth::Server, :prefix => "Server", :hash => instance_hash(:server_auth), :block => block)
  end

  def self.new_handler(name, type, options = {}, &block)
    name = symbolize(name)
    genmodule(name, :parent => Puppet::Auth::Handler, :prefix => type.to_s.capitalize, :hash => instance_hash("handler_#{type}_auth".to_sym), :block => block)
  end

  def self.client
    raise "No auth plugin defined, I think you should care about security" unless Puppet[:auth]
    client_auth(Puppet[:auth])
  end

  def self.server
    raise "No auth plugin defined, I think you should care about security" unless Puppet[:auth]
    server_auth(Puppet[:auth])
  end

  def self.handler(type)
    raise "No auth plugin defined, I think you should care about security" unless Puppet[:auth]
    send("handler_#{type}_auth", Puppet[:auth])
  end

  require 'puppet/auth/server'
  require 'puppet/auth/client'
  require 'puppet/auth/handler'
end