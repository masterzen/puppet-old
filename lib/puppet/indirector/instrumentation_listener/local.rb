require 'puppet/indirector/instrumentation_listener'

class Puppet::Indirector::InstrumentationListener::Local < Puppet::Indirector::Code
  def find(request)
    Puppet::Util::Instrumentation[request.key]
  end

  def search(request)
    Puppet::Util::Instrumentation.listeners
  end

  def save(request)
    res = request.instance
    Puppet::Util::Instrumentation[res.name] = res
  end

  def destroy(request)
    raise Puppet::DevError, "You cannot remove an Instrumentation Listener"
  end
end
