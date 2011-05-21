
Puppet::Auth.new_handler(:ssl, :mongrel) do
  def authenticate(ip, params)
    result = [false, nil]

    # JJM #906 The following dn.match regular expression is forgiving
    # enough to match the two Distinguished Name string contents
    # coming from Apache, Pound or other reverse SSL proxies.
    if dn = params[Puppet[:ssl_client_header]] and dn_matchdata = dn.match(/^.*?CN\s*=\s*(.*)/)
      result[1] = dn_matchdata[1].to_str
      result[0] = (params[Puppet[:ssl_client_verify_header]] == 'SUCCESS')
    else
      result[1] = resolve_node(ip)
    end
    result
  end
end