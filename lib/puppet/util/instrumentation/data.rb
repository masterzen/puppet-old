require 'puppet/indirector'
require 'puppet/util/instrumentation'

# This is just a transport class to be used through the instrumentation_data
# indirection. All the data resides in the real underlying listeners which this
# class delegates to.
class Puppet::Util::Instrumentation::Data
  extend Puppet::Indirector

  indirects :instrumentation_data, :terminus_class => :local

  attr_reader :listener

  def initialize(listener_name)
    @listener = Puppet::Util::Instrumentation[listener_name]
  end

  def name
    @listener.name
  end

  def to_pson(*args)
    result = {
      'document_type' => "Puppet::Util::Instrumentation::Data",
      'data' => { :name => name }.merge(@listener.data)
    }
    result.to_pson(*args)
  end

  def self.from_pson(data)
    raise "Instrumentation Listeners data are read only"
  end
end
