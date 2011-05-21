
Puppet::Auth.new_handler(:ssl, :rack) do

  def authenticate(ip, request)
    result = []
    # if we find SSL info in the headers, use them to get a hostname.
    # try this with :ssl_client_header, which defaults should work for
    # Apache with StdEnvVars.
    if dn = request.env[Puppet[:ssl_client_header]] and dn_matchdata = dn.match(/^.*?CN\s*=\s*(.*)/)
      result[1] = dn_matchdata[1].to_str
      result[0] = (request.env[Puppet[:ssl_client_verify_header]] == 'SUCCESS')
    else
      result[1] = resolve_node(ip)
      result[0] = false
    end
    result
  end
end
