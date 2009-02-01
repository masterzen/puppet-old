begin
    require 'rubygems'
rescue LoadError
    # Nothing; we were just doing this just in case
end

begin
    require 'ldap'
rescue LoadError
    $stderr.puts "Failed to load ruby LDAP library. LDAP functionality will not be available"
end

require 'puppet'
require 'puppet/application'

puppetrun_options = [
    [ "--all",      "-a",       GetoptLong::NO_ARGUMENT ],
    [ "--tag",      "-t",       GetoptLong::REQUIRED_ARGUMENT ],
    [ "--class",    "-c",       GetoptLong::REQUIRED_ARGUMENT ],
    [ "--foreground", "-f",     GetoptLong::NO_ARGUMENT ],
    [ "--debug",    "-d",       GetoptLong::NO_ARGUMENT ],
    [ "--help",     "-h",       GetoptLong::NO_ARGUMENT ],
    [ "--host",                 GetoptLong::REQUIRED_ARGUMENT ],
    [ "--parallel", "-p",       GetoptLong::REQUIRED_ARGUMENT ],
    [ "--ping",     "-P",       GetoptLong::NO_ARGUMENT ],
    [ "--no-fqdn",  "-n",       GetoptLong::NO_ARGUMENT ],
    [ "--test",                 GetoptLong::NO_ARGUMENT ],
    [ "--version",  "-V",       GetoptLong::NO_ARGUMENT ]
]

Puppet::Application.new(:puppetrun, puppetrun_options) do

    should_not_parse_config

    attr_accessor :hosts, :tags, :classes

    dispatch do
        options[:test] ? :test : :main
    end

    command(:test) do
        puts "Skipping execution in test mode"
        exit(0)
    end

    command(:main) do
        require 'puppet/network/client'
        require 'puppet/util/ldap/connection'

        todo = @hosts.dup

        failures = []

        # Now do the actual work
        go = true
        while go
            # If we don't have enough children in process and we still have hosts left to
            # do, then do the next host.
            if @children.length < options[:parallel] and ! todo.empty?
                host = todo.shift
                pid = fork do
                    run_for_host(host)
                end
                @children[pid] = host
            else
                # Else, see if we can reap a process.
                begin
                    pid = Process.wait

                    if host = @children[pid]
                        # Remove our host from the list of children, so the parallelization
                        # continues working.
                        @children.delete(pid)
                        if $?.exitstatus != 0
                            failures << host
                        end
                        print "%s finished with exit code %s\n" % [host, $?.exitstatus]
                    else
                        $stderr.puts "Could not find host for PID %s with status %s" %
                            [pid, $?.exitstatus]
                    end
                rescue Errno::ECHILD
                    # There are no children left, so just exit unless there are still
                    # children left to do.
                    next unless todo.empty?

                    if failures.empty?
                        puts "Finished"
                        exit(0)
                    else
                        puts "Failed: %s" % failures.join(", ")
                        exit(3)
                    end
                end
            end
        end
    end

    def run_for_host(host)
        if options[:ping]
            out = %x{ping -c 1 #{host}}
            unless $? == 0
                $stderr.print "Could not contact %s\n" % host
                next
            end
        end
        client = Puppet::Network::Client.runner.new(
            :Server => host,
            :Port => Puppet[:puppetport]
        )

        print "Triggering %s\n" % host
        begin
            result = client.run(@tags, options[:ignoreschedules], options[:foreground])
        rescue => detail
            $stderr.puts "Host %s failed: %s\n" % [host, detail]
            exit(2)
        end

        case result
        when "success": exit(0)
        when "running":
            $stderr.puts "Host %s is already running" % host
            exit(3)
        else
            $stderr.puts "Host %s returned unknown answer '%s'" % [host, result]
            exit(12)
        end
    end

    preinit do
        [:INT, :TERM].each do |signal|
            trap(signal) do
                $stderr.puts "Cancelling"
                exit(1)
            end
        end
        options[:parallel] = 1
        options[:verbose] = true
        options[:fqdn] = true

        @hosts = []
        @classes = []
        @tags = []
    end

    setup do
        if options[:debug]
            Puppet::Util::Log.level = :debug
        else
            Puppet::Util::Log.level = :info
        end

        # Now parse the config
        Puppet.parse_config

        if Puppet[:node_terminus] == "ldap" and (options[:all] or @classes)
            if options[:all]
                @hosts = Puppet::Node.search("whatever").collect { |node| node.name }
                puts "all: %s" % @hosts.join(", ")
            else
                @hosts = []
                @classes.each do |klass|
                    list = Puppet::Node.search("whatever", :class => klass).collect { |node| node.name }
                    puts "%s: %s" % [klass, list.join(", ")]

                    @hosts += list
                end
            end
        elsif ! @classes.empty?
            $stderr.puts "You must be using LDAP to specify host classes"
            exit(24)
        end

        if @tags.empty?
            @tags = ""
        else
            @tags = @tags.join(",")
        end

        @children = {}

        # If we get a signal, then kill all of our children and get out.
        [:INT, :TERM].each do |signal|
            trap(signal) do
                Puppet.notice "Caught #{signal}; shutting down"
                @children.each do |pid, host|
                    Process.kill("INT", pid)
                end

                waitall

                exit(1)
            end
        end

    end

    option(:version) do |arg|
        puts "%s" % Puppet.version
        exit
    end

    option(:host) do |arg|
        @hosts << arg
    end

    option(:tag) do |arg|
        @tags << arg
    end

    option(:class) do |arg|
        @classes << arg
    end

    option(:no_fqdn) do |arg|
        options[:fqdn] = false
    end

    option(:parallel) do |arg|
        begin
            options[:parallel] = Integer(arg)
        rescue
            $stderr.puts "Could not convert %s to an integer" % arg.inspect
            exit(23)
        end
    end
end
