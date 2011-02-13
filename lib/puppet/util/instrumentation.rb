require 'puppet'
require 'puppet/util/classgen'
require 'puppet/util/instance_loader'

class Puppet::Util::Instrumentation
  extend Puppet::Util::ClassGen
  extend Puppet::Util::InstanceLoader
  extend MonitorMixin

  # we're using a ruby lazy autoloader to prevent a loop when requiring listeners
  # since this class sets up an indirection, but this one is used in Indirection
  autoload :Listener, 'puppet/util/instrumentation/listener'
  autoload :Data, 'puppet/util/instrumentation/data'

  # Set up autoloading and retrieving of instrumentation listeners.
  instance_load :listener, 'puppet/util/instrumentation/listeners'

  class << self
    attr_accessor :listeners, :listeners_of
  end

  # instrumentation layer

  # Triggers an instrumentation
  #
  # Call this method around the instrumentation point
  #   Puppet::Util::Instrumentation.instrument(:my_long_computation) do
  #     ... a long computation
  #   end
  #   
  # This will send an event to all the listeners of "my_long_computation".
  # The same can be achieved faster than using a block by calling start and stop.
  # around the code to instrument.
  def self.instrument(label, data = {})
    id = self.start(label, data)
    yield
  ensure
    self.stop(label, id, data)
  end

  # Triggers a "start" instrumentation event
  # 
  # Important note:
  #  For proper use, the data hash instance used for start should also
  #  be used when calling stop. The idea is to use the current scope
  #  where start is called to retain a reference to 'data' so that it is possible
  #  to send it back to stop.
  #  This way listeners can match start and stop events more easily.
  def self.start(label, data)
    data[:started] = Time.now
    publish(label, :start, data)
    data[:id] = next_id
  end

  # Triggers a "stop" instrumentation event
  def self.stop(label, id, data)
    data[:finished] = Time.now
    publish(label, :stop, data)
  end

  def self.publish(label, event, data)
    listeners_of(label).each do |k,l|
      l.notify(label, event, data)
    end
  end

  def self.listeners
    @listeners.values
  end

  def self.listeners_of(label)
    synchronize {
      @listeners_of[label] ||= @listeners.select do |k,l|
        l.listen_to?(label)
      end
    }
  end

  # Adds a new listener
  # 
  # Usage:
  #   Puppet::Util::Instrumentation.new_listener(:my_instrumentation, pattern) do
  # 
  #     def notify(label, data)
  #       ... do something for data...
  #     end
  #   end
  # 
  # It is possible to use a "pattern". The listener will be notified only
  # if the pattern match the label of the event.
  # The pattern can be a symbol, a string or a regex.
  # If no pattern is provided, then the listener will be called for every events
  def self.new_listener(name, options = {}, &block)
    Puppet.debug "new listener called #{name}"
    name = symbolize(name)
    listener = genclass(name, :hash => instance_hash(:listener), :block => block)
    listener.send(:define_method, :name) do
      name
    end
    subscribe(listener.new, options[:label_pattern], options[:event])
  end

  def self.subscribe(listener, label_pattern, event)
    synchronize {
      Puppet.debug "registering instrumentation listener #{listener.name}"
      @listeners[listener.name] = Listener.new(listener, label_pattern, event)
      rehash
    }
  end

  def self.unsubscribe(listener)
    synchronize {
      Puppet.info "unregistering instrumentation listener #{listener.name}"
      @listeners.delete(listener.name.to_s)
      rehash
    }
  end

  def self.init
    synchronize {
      @listeners ||= {}
      @listeners_of ||= {}
      instance_loader(:listener).loadall
    }
  end

  def self.rehash
    @listeners_of.clear
  end

  def self.clear
    synchronize {
      @listeners = {}
      @listeners_of = {}
      @id = 0
    }
  end

  def self.[](key)
    synchronize {
      key = symbolize(key)
      @listeners[key]
    }
  end

  def self.[]=(key, value)
    synchronize {
      key = symbolize(key)
      @listeners[key] = value
      rehash
    }
  end

  private

  def self.next_id
    synchronize {
      id = @id || 0
      @id = id + 1
      id
    }
  end
end
