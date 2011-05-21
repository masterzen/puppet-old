require 'webrick/httpauth'

Puppet::Auth.new_handler(:http_basic, :webrick) do

  # Add all of the ssl cert information.
  def self.setup
    raise "No htpasswd file at #{Puppet.settings[:http_basic_htpasswd]}" unless FileTest.exists?(Puppet.settings[:http_basic_htpasswd])
    # no more webrick options
    {}
  end

  def authenticate(ip, request)
    @htpasswd ||= WEBrick::HTTPAuth::Htpasswd.new(Puppet.settings[:http_basic_htpasswd])
    @authenticator ||= WEBrick::HTTPAuth::BasicAuth.new(
      :UserDB => @htpasswd,
      :Realm => "Puppet"
    )
    result = [false, nil]
    begin
      @authenticator.authenticate(request, {})
      result[0] = true
      result[1] = request.user # our node is the given user
    rescue WEBrick::HTTPStatus::Unauthorized => e
      # ignored
    end

    result[1] ||= resolve_node(ip)
    result
  end
end