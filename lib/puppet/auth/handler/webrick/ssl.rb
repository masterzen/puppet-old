require 'puppet/ssl/host'
require 'puppet/ssl/certificate'

Puppet::Auth.new_handler(:ssl, :webrick) do
  # Add all of the ssl cert information.
  def self.setup
    results = {}

    # Get the cached copy.  We know it's been generated, too.
    host = Puppet::SSL::Host.localhost

    raise Puppet::Error, "Could not retrieve certificate for #{host.name} and not running on a valid certificate authority" unless host.certificate

    results[:SSLPrivateKey] = host.key.content
    results[:SSLCertificate] = host.certificate.content
    results[:SSLStartImmediately] = true
    results[:SSLEnable] = true

    raise Puppet::Error, "Could not find CA certificate" unless Puppet::SSL::Certificate.indirection.find(Puppet::SSL::CA_NAME)

    results[:SSLCACertificateFile] = Puppet[:localcacert]
    results[:SSLVerifyClient] = OpenSSL::SSL::VERIFY_PEER

    results[:SSLCertificateStore] = host.ssl_store

    results
  end

  def authenticate(ip, request)
    result = [false, nil]
    if cert = request.client_cert and nameary = cert.subject.to_a.find { |ary| ary[0] == "CN" }
      result[1] = nameary[1]
      result[0] = true
    else
      result[1] = resolve_node(ip)
    end
    result
  end
end