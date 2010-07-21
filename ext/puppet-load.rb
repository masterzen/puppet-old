#!/usr/bin/env ruby
# Do an initial trap, so that cancels don't get a stack trace.
trap(:INT) do
    $stderr.puts "Cancelling startup"
    exit(1)
end

require 'rubygems'
require 'eventmachine'
require 'em-http'
require 'getoptlong'

require 'puppet'

$cmdargs = [
    [ "--concurrency",  "-c", GetoptLong::REQUIRED_ARGUMENT       ],
    [ "--fqdn",     "-F", GetoptLong::REQUIRED_ARGUMENT ],
    [ "--facts",          GetoptLong::REQUIRED_ARGUMENT ],
    [ "--repeat",   "-r", GetoptLong::REQUIRED_ARGUMENT ],
    [ "--node",     "-n", GetoptLong::REQUIRED_ARGUMENT ],
    [ "--debug",    "-d", GetoptLong::NO_ARGUMENT       ],
    [ "--help",     "-h", GetoptLong::NO_ARGUMENT       ],
    [ "--list",     "-l", GetoptLong::NO_ARGUMENT       ],
    [ "--verbose",  "-v", GetoptLong::NO_ARGUMENT       ],
    [ "--version",  "-V", GetoptLong::NO_ARGUMENT       ],
]

# Add all of the config parameters as valid $options.
Puppet.settings.addargs($cmdargs)
Puppet::Util::Log.newdestination(:console)

times = {}

def read_facts(file)
    YAML.load(File.read(file))
end


result = GetoptLong.new(*$cmdargs)

$args = {}
$options = {:repeat => 1, :concurrency => 1, :pause => false, :nodes => []}

begin
    result.each { |opt,arg|
        case opt
            when "--concurrency"
                begin
                    $options[:concurrency] = Integer(arg)
                rescue => detail
                    $stderr.puts "The argument to 'fork' must be an integer"
                    exit(14)
                end
            when "--fqdn"
                $options[:fqdn] = arg
            when "--facts"
                $options[:facts] = arg
            when "--repeat"
                $options[:repeat] = Integer(arg)
            when "--help"
                if Puppet.features.usage?
                    RDoc::usage && exit
                else
                    puts "No help available unless you have RDoc::usage installed"
                    exit
                end
            when "--version"
                puts "%s" % Puppet.version
                exit
            when "--verbose"
                Puppet::Util::Log.level = :info
                Puppet::Util::Log.newdestination(:console)
            when "--debug"
                Puppet::Util::Log.level = :debug
                Puppet::Util::Log.newdestination(:console)
            when "--node"
                $options[:nodes] << arg
            else
                Puppet.settings.handlearg(opt, arg)
        end
    }
rescue GetoptLong::InvalidOption => detail
    $stderr.puts detail
    $stderr.puts "Try '#{$0} --help'"
    exit(1)
end

# Now parse the config
Puppet.parse_config

$options[:nodes] << Puppet.settings[:certname] if $options[:nodes].empty?

unless $options[:facts] and facts = read_facts($options[:facts])
    unless facts = Puppet::Node::Facts.find($options[:nodes][0])
        raise "Could not find facts for %s" % $options[:nodes][0]
    end
end

if host = $options[:fqdn]
    facts.values["fqdn"] = host
    facts.values["hostname"] = host.sub(/\..+/, '')
    facts.values["domain"] = host.sub(/^[^.]+\./, '')
end
facts.values["lsddistcodename"] = 'lenny'

headers = {:facts_format => "b64_zlib_yaml", :facts => CGI.escape(facts.render(:b64_zlib_yaml))}

class RequestPool
  include EventMachine::Deferrable

  attr_reader :requests, :responses, :times
  attr_reader :repeat, :concurrency, :max_request

  def initialize(concurrency, repeat, parameters)
    @parameters = parameters
    @current_request = 0
    @max_request = repeat * concurrency
    @repeat = repeat
    @concurrency = concurrency
    @requests = []
    @responses = {:succeeded => [], :failed => []}
    @times = {}

    # initial spawn
    (1..concurrency).each do |i|
      spawn
    end

  end

  def spawn_request(index)
    EventMachine::HttpRequest.new("https://#{Puppet.settings[:server]}:#{Puppet.settings[:masterport]}/production/catalog/#{$options[:fqdn]}").get(
      :port => Puppet.settings[:masterport],
      :query => @parameters,
      :timeout => 180,
      :head => { "Accept" => "pson, yaml, b64_zlib_yaml, marshal, dot, raw", "Accept-Encoding" => "gzip, deflate" },
      :ssl => { :private_key_file => "#{Puppet.settings[:privatekeydir]}/#{$options[:fqdn]}.pem",
                :cert_chain_file => "#{Puppet.settings[:certdir]}/#{$options[:fqdn]}.pem",
                :verify_peer => false } ) do
        @times[index] = Time.now
    end
  end

  def add(index, conn)
    @requests.push(conn)

    conn.callback {
      @times[index] = Time.now - @times[index]
      if conn.response_header.status >= 200 && conn.response_header.status < 300
        @responses[:succeeded].push(conn)
      else
        @responses[:failed].push(conn)
      end
      check_progress
    }

    conn.errback {
      @times[index] = Time.now - @times[index]
      @responses[:failed].push(conn)
      check_progress
    }
  end

  def all_responses
    @responses[:succeeded] + @responses[:failed]
  end

  protected

  def check_progress
    spawn unless all_spawned?
    succeed if all_finished?
  end

  def all_spawned?
    @requests.size >= max_request
  end

  def all_finished?
    @responses[:failed].size + @responses[:succeeded].size >= max_request
  end

  def spawn
    add(@current_request, spawn_request(@current_request))
    @current_request += 1
  end
end


def mean(array)
  array.inject(0) { |sum, x| sum += x } / array.size.to_f
end

def median(array)
  array = array.sort
  m_pos = array.size / 2
  return array.size % 2 == 1 ? array[m_pos] : mean(array[m_pos-1..m_pos])
end

def format_bytes(bytes)
  if bytes < 1024
    "%.2f B" % bytes
  elsif bytes < 1024 * 1024
    "%.2f KiB" % (bytes/1024.0)
  else
    "%.2f MiB" % (bytes/(1024.0*1024.0))
  end
end

EM::run {

  start = Time.now
  multi = RequestPool.new($options[:concurrency], $options[:repeat], headers)

  multi.callback do
    duration = Time.now - start
    puts "#{multi.max_request} requests finished in #{duration} s"
    puts "#{multi.responses[:failed].size} requests failed"
    puts "Availability: %3.2f %%" % (100.0*multi.responses[:succeeded].size/(multi.responses[:succeeded].size+multi.responses[:failed].size))

    minmax = multi.times.values.minmax
    all_time = multi.times.values.reduce(:+)

    puts "\nTime (s):"
    puts "\tmin: #{minmax[0]} s"
    puts "\tmax: #{minmax[1]} s"
    puts "\taverage: #{mean(multi.times.values)} s"
    puts "\tmedian: #{median(multi.times.values)} s"

    puts "\nConcurrency: %.2f" % (all_time/duration)
    puts "Transaction Rate (tps): %.2f t/s" % (multi.max_request / duration)

    transferred = multi.all_responses.reduce(0) do |bytes, r|
      bytes += r.response_header.content_length
    end
    puts "\nReceived bytes: #{format_bytes(transferred)}"
    puts "Throughput: %.5f MiB/s" % (transferred/duration/(1024.0*1024.0))


    # this is the end
    EventMachine.stop
  end
}


