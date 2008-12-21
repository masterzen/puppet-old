require 'puppet'
require 'getoptlong'

# This class handles all the aspects of a Puppet application/executable
# * setting up options
# * setting up logs
# * choosing what to run
#
# === Usage
# The application is a Puppet::Application object that register itself in the list
# of available application. Each application needs a +name+ and a getopt +options+
# description array.
#
# The executable uses the application object like this:
#      Puppet::Application[:example].run
#
# 
# options = [
#                   [ "--all",      "-a",  GetoptLong::NO_ARGUMENT ],
#                   [ "--debug",    "-d",  GetoptLong::NO_ARGUMENT ] ]
# Puppet::Application.new(:example, options) do
# 
#     command do
#         ARGV.shift
#     end
# 
#     option(:all) do
#         @all = true
#     end
#     
#     command(:read) do
#         # read action
#     end
# 
#     command(:write) do
#         # writeaction
#     end
# 
# end
#
# === Options
# When creating a Puppet::Application, the caller should pass an array in the GetoptLong 
# options format to the initializer.
# This application then parses ARGV and on each found options:
# * If the option has been defined in the options array:
#  * If the application defined an option with option(<option-name>) it's block executed
#  * Or, a global options is set either with the argument or true if the option doesn't require an argument 
# * If the option is unknown, and an option(:unknown) was registered then the argument is managed by it.
# * and finally, if none of the above has worked, the option is sent to Puppet.settings
#
# --help is managed directly by the Puppet::Application class
#
# === Setup
# Applications can use the setup block to perform any initialization.
# The defaul +setup+ behaviour is to: read Puppet configuration and manage log level and destination
#
# === What and how to run
# If the +dispatch+ block is defined it is called. This block should return the name of the registered command
# to be run.
# If it doesn't exist, it defaults to execute the +main+ command if defined.
#
class Puppet::Application
    include Puppet::Util

    @@applications = {}
    class << self
        include Puppet::Util
    end

    attr_reader :options

    def self.[](name)
        name = symbolize(name)
        @@applications[name]
    end

    def should_parse_config
        @parse_config = true
    end

    def should_not_parse_config
        @parse_config = false
    end

    def should_parse_config?
        unless @parse_config.nil?
            return @parse_config
        end
        @parse_config = true
    end

    # used to declare a new command
    def command(name, &block)
        meta_def(symbolize(name), &block)
    end

    # used to declare code that handle an option
    def option(name, &block)
        fname = "handle_#{name}"
        meta_def(symbolize(fname), &block)
    end

    # used to declare accessor in a more natural way in the 
    # various applications
    def attr_accessor(*args)
        args.each do |arg|
            meta_def(arg) do
                instance_variable_get("@#{arg}".to_sym)
            end
            meta_def("#{arg}=") do |value|
                instance_variable_set("@#{arg}".to_sym, value)
            end
        end
    end

    # used to declare code run instead the default setup
    def setup(&block)
        meta_def(:run_setup, &block)
    end

    # used to declare code to choose which command to run
    def dispatch(&block)
        meta_def(:get_command, &block)
    end

    # used to execute code before running anything else
    def preinit(&block)
        meta_def(:run_preinit, &block)
    end

    def initialize(name, options = [], &block)
        name = symbolize(name)

        @getopt = options

        setup do 
            default_setup
        end

        dispatch do
            :main
        end

        # empty by default
        preinit do
        end

        @options = {}

        instance_eval(&block) if block_given?

        @@applications[name] = self
    end

    # This is the main application entry point
    def run
        run_preinit
        parse_options
        Puppet.parse_config if should_parse_config?
        run_setup
        run_command
    end

    def main
        raise NotImplementedError, "No valid command or main"
    end

    def run_command
        if command = get_command() and respond_to?(command)
            send(command)
        else
            main
        end
    end

    def default_setup
        # Handle the logging settings
        if options[:debug] or options[:verbose]
            Puppet::Util::Log.newdestination(:console)
            if options[:debug]
                Puppet::Util::Log.level = :debug
            else
                Puppet::Util::Log.level = :info
            end
        end

        unless options[:setdest]
            Puppet::Util::Log.newdestination(:syslog)
        end
    end

    def parse_options
        option_names = @getopt.collect { |a| a[0] }

        Puppet.settings.addargs(@getopt)
        result = GetoptLong.new(*@getopt)

        begin
            result.each do |opt, arg|
                key = opt.gsub(/^--/, '').gsub(/-/,'_').to_sym

                method = "handle_#{key}"
                if respond_to?(method)
                    send(method, arg)
                elsif option_names.include?(opt)
                    @options[key] = arg || true
                else
                    unless respond_to?(:handle_unknown) and send(:handle_unknown, opt, arg)
                        Puppet.settings.handlearg(opt, arg)
                    end
                end
            end
        rescue GetoptLong::InvalidOption => detail
            $stderr.puts "Try '#{$0} --help'"
            exit(1)
        end
    end

    # this is used for testing
    def self.exit(code)
        exit(code)
    end

    def handle_help(arg)
        if Puppet.features.usage?
            RDoc::usage && exit
        else
            puts "No help available unless you have RDoc::usage installed"
            exit
        end
    end

end