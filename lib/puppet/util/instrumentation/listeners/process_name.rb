require 'monitor'

# Unlike the other instrumentation plugins, this one doesn't gives back
# data. Instead it changes the process name of the currently running process
# with the last labels and data. 
Puppet::Util::Instrumentation.new_listener(:process_name) do
  # start scrolling when process name is longer than
  SCROLL_LENGTH = 50

  attr_accessor :active, :reason

  def notify(label, event, data)
    start(label) if event == :start
    stop if event == :stop
  end

  def start(activity)
    @scroller ||= Thread.new do
      loop do
        scroll
        sleep 1
      end
    end

    push_activity(Thread.current, activity)
  end

  def stop()
    pop_activity(Thread.current)
  end

  def setproctitle
    @oldname ||= $0
    $0 = "#{base}: " + rotate(process_name,@x)
  end

  def push_activity(thread, activity)
    mutex.synchronize do
      @reason ||= {}
      @reason[thread] ||= []
      @reason[thread].push(activity)
      setproctitle
    end
  end

  def pop_activity(thread)
    mutex.synchronize do
      @reason[thread].pop
      if @reason[thread].empty?
        @reason.delete(thread)
      end
      setproctitle
    end
  end

  def process_name
    out = (@reason || {}).inject([]) do |out, reason|
      out << "#{thread_id(reason[0])} #{reason[1].join(',')}"
    end
    out.join(' | ')
  end

  # certainly non-portable
  def thread_id(thread)
    thread.inspect.gsub(/^#<.*:0x([a-f0-9]+) .*>$/, '\1')
  end

  def rotate(string, steps)
    steps ||= 0
    if string.length > 0 && steps > 0
      steps = steps % string.length
      return string[steps..string.length].concat " -- #{string[0..(steps-1)]}"
    end
    string
  end

  def base
    basename = case Puppet.run_mode.name
    when :master
      "master"
    when :agent
      "agent"
    else
      "puppet"
    end
  end

  def mutex
    #Thread.exclusive {
      @mutex ||= Sync.new
    #}
    @mutex
  end

  def scroll
    @x ||= 1
    return if process_name.length < SCROLL_LENGTH
    mutex.synchronize do
      setproctitle
      @x += 1
    end
  end
end