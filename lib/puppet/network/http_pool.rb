require 'puppet/ssl/host'
require 'net/https'
require 'puppet/util/cacher'

module Puppet::Network; end

# Manage Net::HTTP instances for keep-alive.
module Puppet::Network::HttpPool
  class << self
    include Puppet::Util::Cacher

    private

    cached_attr(:http_cache) { Hash.new }
  end

  # 2008/03/23
  # LAK:WARNING: Enabling this has a high propability of
  # causing corrupt files and who knows what else.  See #1010.
  HTTP_KEEP_ALIVE = false

  def self.keep_alive?
    HTTP_KEEP_ALIVE
  end

  # Clear our http cache, closing all connections.
  def self.clear_http_instances
    http_cache.each do |name, connection|
      connection.finish if connection.started?
    end
    Puppet::Util::Cacher.expire
  end

  # Make sure we set the driver up when we read the cert in.
  def self.read_cert
    if val = super # This calls read_cert from the Puppet::SSLCertificates::Support module.
      # Clear out all of our connections, since they previously had no cert and now they
      # should have them.
      clear_http_instances
      return val
    else
      return false
    end
  end

  # Use cert information from a Puppet client to set up the http object.
  def self.auth_setup(http)
    Puppet::Auth.client.setup_http_client(http)
  end

  class AuthHTTPWrapper

    attr_reader :http

    def initialize(http)
      @http = http
    end

    [:get,:delete].each do |m|
      define_method(m) do |path, initheaders|
        req = Net::HTTP.const_get(m.to_s.capitalize).new(path, initheaders)
        Puppet::Auth.client.setup_request(req)
        @http.request(req)
      end
    end

    [:post,:put].each do |m|
      define_method(m) do |path, data, initheaders|
        req = Net::HTTP.const_get(m.to_s.capitalize).new(path, initheaders)
        Puppet::Auth.client.setup_request(req)
        @http.request(req, data)
      end
    end

    def method_missing(name, *args)
      @http.send(name, *args)
    end
  end

  # Retrieve a cached http instance if caching is enabled, else return
  # a new one.
  def self.http_instance(host, port, reset = false)
    # We overwrite the uninitialized @http here with a cached one.
    key = "#{host}:#{port}"

    # Return our cached instance if we've got a cache, as long as we're not
    # resetting the instance.
    if keep_alive?
      return http_cache[key] if ! reset and http_cache[key]

      # Clean up old connections if we have them.
      if http = http_cache[key]
        http_cache.delete(key)
        http.finish if http.started?
      end
    end

    args = [host, port]
    if Puppet[:http_proxy_host] == "none"
      args << nil << nil
    else
      args << Puppet[:http_proxy_host] << Puppet[:http_proxy_port]
    end
    http = AuthHTTPWrapper.new(Net::HTTP.new(*args))

    # Use configured timeout (#1176)
    http.read_timeout = Puppet[:configtimeout]
    http.open_timeout = Puppet[:configtimeout]

    auth_setup(http)

    http_cache[key] = http if keep_alive?

    http
  end
end
