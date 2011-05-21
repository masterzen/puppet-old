require 'puppet/ssl/host'

Puppet::Auth.new_client(:ssl) do

  def self.init(options)
    Puppet.settings.use :ssl

    # We need to specify a ca location for all of the SSL-related i
    # indirected classes to work; in fingerprint mode we just need
    # access to the local files and we don't need a ca.
    Puppet::SSL::Host.ca_location = options[:fingerprint] ? :none : :remote
  end

  def self.setup(options)
    waitforcert = options[:waitforcert] || (Puppet[:onetime] ? 0 : 120)
    cert = Puppet::SSL::Host.new.wait_for_cert(waitforcert) unless options[:fingerprint]
  end

  def self.setup_http_client(http)
    http.use_ssl = true

    # Just no-op if we don't have certs.
    return false unless FileTest.exist?(Puppet[:hostcert]) and FileTest.exist?(Puppet[:localcacert])

    http.cert_store = ssl_host.ssl_store
    http.ca_file = Puppet[:localcacert]
    http.cert = ssl_host.certificate.content
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.key = ssl_host.key.content

    # Pop open the http client a little; older versions of Net::HTTP(s) didn't
    # give us a reader for ca_file... Grr...
    class << http; attr_accessor :ca_file; end
  end

  def self.setup_request(request)
  end

  # Use the global localhost instance.
  def self.ssl_host
    Puppet::SSL::Host.localhost
  end
end