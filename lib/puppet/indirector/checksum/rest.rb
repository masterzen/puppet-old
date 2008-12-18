require 'puppet/checksum'
require 'puppet/indirector/rest'

class Puppet::Checksum::Rest < Puppet::Indirector::REST
    desc "This is a REST based mechanism to send/retrieve file to/from the filebucket"
end
