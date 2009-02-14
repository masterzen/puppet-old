require 'puppet'
require 'puppet/application'
require 'puppet/network/handler'
require 'puppet/network/client'

puppet_options = [
    [ "--debug",	"-d",			GetoptLong::NO_ARGUMENT ],
    [ "--help",		"-h",			GetoptLong::NO_ARGUMENT ],
    [ "--logdest",	"-l",			GetoptLong::REQUIRED_ARGUMENT ],
    [ "--execute",	"-e",			GetoptLong::REQUIRED_ARGUMENT ],
    [ "--loadclasses", "-L",		GetoptLong::NO_ARGUMENT ],
    [ "--verbose",  "-v",			GetoptLong::NO_ARGUMENT ],
    [ "--use-nodes",    			GetoptLong::NO_ARGUMENT ],
    [ "--detailed-exitcodes",		GetoptLong::NO_ARGUMENT ],
    [ "--version",  "-V",           GetoptLong::NO_ARGUMENT ]
]

Puppet::Application.new(:puppet, puppet_options) do

    should_parse_config

    dispatch do
        return Puppet[:parseonly] ? :parseonly : :main
    end

    command(:parseonly) do
        begin
            Puppet::Parser::Interpreter.new.parser(Puppet[:environment])
        rescue => detail
            Puppet.err detail
            exit 1
        end
        exit 0
    end

    command(:main) do
        # Collect our facts.
        facts = Puppet::Node::Facts.find(Puppet[:certname])

        # Find our Node
        unless node = Puppet::Node.find(Puppet[:certname])
            raise "Could not find node %s" % Puppet[:certname]
        end

        # Merge in the facts.
        node.merge(facts.values)

        # Allow users to load the classes that puppetd creates.
        if options[:loadclasses]
            file = Puppet[:classfile]
            if FileTest.exists?(file)
                unless FileTest.readable?(file)
                    $stderr.puts "%s is not readable" % file
                    exit(63)
                end
                node.classes = File.read(file).split(/[\s\n]+/)
            end
        end

        begin
            # Compile our catalog
            starttime = Time.now
            catalog = Puppet::Resource::Catalog.find(node.name, :use_node => node)

            # Translate it to a RAL catalog
            catalog = catalog.to_ral

            catalog.host_config = true if Puppet[:graph] or Puppet[:report]

            catalog.finalize

            catalog.retrieval_duration = Time.now - starttime

            # And apply it
            transaction = catalog.apply

            status = 0
            if not Puppet[:noop] and options[:detailed_exits] then
                transaction.generate_report
                status |= 2 if transaction.report.metrics["changes"][:total] > 0
                status |= 4 if transaction.report.metrics["resources"][:failed] > 0
            end
            exit(status)
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            if detail.is_a?(XMLRPC::FaultException)
                $stderr.puts detail.message
            else
                $stderr.puts detail
            end
            exit(1)
        end
    end

    setup do
        # Now parse the config
        if Puppet[:config] and File.exists? Puppet[:config]
            Puppet.settings.parse(Puppet[:config])
        end

        if Puppet.settings.print_configs?
            exit(Puppet.settings.print_configs ? 0 : 1)
        end

        # If noop is set, then also enable diffs
        if Puppet[:noop]
            Puppet[:show_diff] = true
        end

        unless options[:logset]
            Puppet::Util::Log.newdestination(:console)
        end
        client = nil
        server = nil

        trap(:INT) do
            $stderr.puts "Exiting"
            exit(1)
        end

        if options[:debug]
            Puppet::Util::Log.level = :debug
        elsif options[:verbose]
            Puppet::Util::Log.level = :info
        end

        # Set our code or file to use.
        if options[:code] or ARGV.length == 0
            Puppet[:code] = options[:code] || STDIN.read
        else
            Puppet[:manifest] = ARGV.shift
        end
    end


    option(:logdest) do |arg|
        begin
            Puppet::Util::Log.newdestination(arg)
            options[:logset] = true
        rescue => detail
            $stderr.puts detail.to_s
        end
    end

    option(:version) do |arg|
        puts "%s" % Puppet.version
        exit
    end
end