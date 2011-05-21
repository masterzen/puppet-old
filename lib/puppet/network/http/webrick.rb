require 'webrick'
require 'webrick/https'
require 'puppet/network/http/webrick/rest'
require 'puppet/network/xmlrpc/webrick_servlet'
require 'thread'

require 'puppet/ssl/certificate'
require 'puppet/ssl/certificate_revocation_list'

class Puppet::Network::HTTP::WEBrick
  def initialize(args = {})
    @listening = false
    @mutex = Mutex.new
  end

  def self.class_for_protocol(protocol)
    return Puppet::Network::HTTP::WEBrickREST if protocol.to_sym == :rest
    raise "Unknown protocol [#{protocol}]."
  end

  def listen(args = {})
    raise ArgumentError, ":protocols must be specified." if !args[:protocols] or args[:protocols].empty?
    raise ArgumentError, ":address must be specified." unless args[:address]
    raise ArgumentError, ":port must be specified." unless args[:port]

    @protocols = args[:protocols]
    @xmlrpc_handlers = args[:xmlrpc_handlers]

    arguments = {:BindAddress => args[:address], :Port => args[:port]}
    arguments.merge!(setup_logger)
    arguments.merge!(Puppet::Auth.handler(:webrick).setup)

    @server = WEBrick::HTTPServer.new(arguments)
    @server.listeners.each { |l| l.respond_to?(:start_immediately) && l.start_immediately = false }

    setup_handlers

    @mutex.synchronize do
      raise "WEBrick server is already listening" if @listening
      @listening = true
      @thread = Thread.new {
        @server.start { |sock|
          raise "Client disconnected before connection could be established" unless IO.select([sock],nil,nil,0.1)
          sock.accept if sock.respond_to?(:accept)
          @server.run(sock)
        }
      }
      sleep 0.1 until @server.status == :Running
    end
  end

  def unlisten
    @mutex.synchronize do
      raise "WEBrick server is not listening" unless @listening
      @server.shutdown
      @thread.join
      @server = nil
      @listening = false
    end
  end

  def listening?
    @mutex.synchronize do
      @listening
    end
  end

  # Configure our http log file.
  def setup_logger
    # Make sure the settings are all ready for us.
    Puppet.settings.use(:main, :ssl, Puppet[:name])

    if Puppet.run_mode.master?
      file = Puppet[:masterhttplog]
    else
      file = Puppet[:httplog]
    end

    # open the log manually to prevent file descriptor leak
    file_io = ::File.open(file, "a+")
    file_io.sync
    file_io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)

    args = [file_io]
    args << WEBrick::Log::DEBUG if Puppet::Util::Log.level == :debug

    logger = WEBrick::Log.new(*args)
    return :Logger => logger, :AccessLog => [
      [logger, WEBrick::AccessLog::COMMON_LOG_FORMAT ],
      [logger, WEBrick::AccessLog::REFERER_LOG_FORMAT ]
    ]
  end

  private

  def setup_handlers
    # Set up the new-style protocols.
    klass = self.class.class_for_protocol(:rest)
    @server.mount('/', klass, :this_value_is_apparently_necessary_but_unused)

    # And then set up xmlrpc, if configured.
    @server.mount("/RPC2", xmlrpc_servlet) if @protocols.include?(:xmlrpc) and ! @xmlrpc_handlers.empty?
  end

  # Create our xmlrpc servlet, which provides backward compatibility.
  def xmlrpc_servlet
    handlers = @xmlrpc_handlers.collect { |handler|
      unless hclass = Puppet::Network::Handler.handler(handler)
        raise "Invalid xmlrpc handler #{handler}"
      end
      hclass.new({})
    }
    Puppet::Network::XMLRPC::WEBrickServlet.new handlers
  end
end
