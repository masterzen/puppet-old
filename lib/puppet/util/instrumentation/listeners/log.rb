require 'monitor'

# This is an example instrumentation listener that stores the last
# 20 instrumentated probe run time.
Puppet::Util::Instrumentation.new_listener(:log) do

  SIZE = 20

  attr_accessor :last_logs

  def notify(label, event, data)
    return if event == :start
    @last_logs ||= {}.extend(MonitorMixin)
    log_line = "#{label} took #{data[:finished] - data[:started]}"
    @last_logs.synchronize {
      (@last_logs[label] ||= []) << log_line
      @last_logs[label].shift if @last_logs[label].length > SIZE
    }
  end

  def data
    @last_logs
  end
end