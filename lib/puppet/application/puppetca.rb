require 'puppet'
require 'puppet/application'
require 'puppet/ssl/certificate_authority'

puppetca_options = [
    [ "--all",      "-a",  GetoptLong::NO_ARGUMENT ],
    [ "--clean",    "-c",  GetoptLong::NO_ARGUMENT ],
    [ "--debug",    "-d",  GetoptLong::NO_ARGUMENT ],
    [ "--generate", "-g",  GetoptLong::NO_ARGUMENT ],
    [ "--help",     "-h",  GetoptLong::NO_ARGUMENT ],
    [ "--list",     "-l",  GetoptLong::NO_ARGUMENT ],
    [ "--print",    "-p",  GetoptLong::NO_ARGUMENT ],
    [ "--revoke",   "-r",  GetoptLong::NO_ARGUMENT ],
    [ "--sign",     "-s",  GetoptLong::NO_ARGUMENT ],
    [ "--verify",          GetoptLong::NO_ARGUMENT ],
	[ "--version",	"-V",  GetoptLong::NO_ARGUMENT ],
    [ "--verbose",  "-v",  GetoptLong::NO_ARGUMENT ]
]

Puppet::Application.new(:puppetca, puppetca_options) do

    should_parse_config

    attr_accessor :mode, :all, :ca

    command(:main) do
        if @all
            hosts = :all
        else
            hosts = ARGV.collect { |h| puts h; h.downcase }
        end
        begin
            @ca.apply(@mode, :to => hosts)
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            puts detail.to_s
            exit(24)
        end
    end

    setup do
        if Puppet.settings.print_configs?
            exit(Puppet.settings.print_configs ? 0 : 1)
        end

        Puppet::Util::Log.newdestination :console

        Puppet::SSL::Host.ca_location = :local

        begin
            @ca = Puppet::SSL::CertificateAuthority.new
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            puts detail.to_s
            exit(23)
        end
    end

    option(:unknown) do |opt, arg|
        modes = Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS
        tmp = opt.sub("--", '').to_sym
        @mode = modes.include?(tmp) ? tmp : nil
        true
    end

    option(:clean) do |arg|
        @mode = :destroy
    end

    option(:all) do |arg|
        @all = true
    end

    option(:verbose) do |arg|
        Puppet::Util::Log.level = :info
    end

    option(:debug) do |arg|
        Puppet::Util::Log.level = :debug
    end
end