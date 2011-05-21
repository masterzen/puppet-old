
Puppet::Auth.new_handler(:http_basic, :mongrel) do
  def authenticate(ip, params)
    # we hope this is correctly handled in the reverse proxy
    [true, resolve_node(ip)]
  end
end