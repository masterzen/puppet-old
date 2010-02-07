#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/content_stream'
require 'puppet/indirector/file_content'
require 'puppet/indirector/rest'
require 'puppet/network/deferred_response'

class Puppet::Indirector::FileContent::Rest < Puppet::Indirector::REST
    desc "Retrieve file contents via a REST HTTP interface."

    # let's cheat a little bit:
    # instead of returning a "model" we're returning something pretending to be a model
    # which instead will fire a deferred request when needed
    def find(request)
        return Puppet::FileServing::ContentStream.create(Puppet::Network::DeferredResponse.new(request, indirection2uri(request), headers, self))
    end
end
