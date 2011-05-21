
Puppet::Auth.new_handler(:http_basic, :rack) do
  def authenticate(ip, params)
    # we hope this is correctly handled in Apache
    [true, resolve_node(ip)]
  end
end
