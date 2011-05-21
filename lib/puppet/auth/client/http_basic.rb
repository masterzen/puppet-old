
Puppet::Auth.new_client(:http_basic) do

  def self.init(options)
  end

  def self.setup(options)
  end

  def self.setup_http_client(http)
  end

  def self.setup_request(request)
    request.basic_auth(Puppet.settings[:http_basic_username], Puppet.settings[:http_basic_password])
  end
end