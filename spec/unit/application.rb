#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/application'
require 'puppet'
require 'getoptlong'

describe Puppet::Application do

    before :each do
        @app = Puppet::Application.new(:test)
    end

    it "should have a run entry-point" do
        @app.should respond_to(:run)
    end

    it "should have a read accessor to options" do
        @app.should respond_to(:options)
    end

    it "should create a default run_setup method" do
        @app.should respond_to(:run_setup)
    end

    it "should create a default run_preinit method" do
        @app.should respond_to(:run_preinit)
    end

    it "should create a default get_command method" do
        @app.should respond_to(:get_command)
    end

    it "should return :main as default get_command" do
        @app.get_command.should == :main
    end

    describe "when parsing command-line options" do

        before :each do
            @argv_bak = ARGV.dup
            ARGV.clear

            Puppet.settings.stubs(:addargs)
            @opt = stub 'opt', :each => nil
            GetoptLong.stubs(:new).returns(@opt)
        end

        after :each do
            ARGV.clear
            ARGV << @argv_bak
        end

        it "should give options to Puppet.settings.addargs" do
            options = []

            Puppet.settings.expects(:addargs).with(options)

            Puppet::Application.new(:test, options).parse_options
        end

        it "should scan command line arguments with Getopt" do
            options = []

            GetoptLong.expects(:new).returns(stub_everything)

            Puppet::Application.new(:test, options).parse_options
        end

        it "should loop around one argument given on command line" do
            options = [[ "--one", "-o", GetoptLong::NO_ARGUMENT ]]
            ARGV << [ "--one" ]
            Puppet.settings.stubs(:handlearg)

            @opt.expects(:each).yields("--one", nil)

            Puppet::Application.new(:test, options).parse_options
        end

        it "should loop around all arguments given on command line" do
            options = [ [ "--one", "-o", GetoptLong::NO_ARGUMENT ],
                        [ "--two", "-t", GetoptLong::NO_ARGUMENT ]
                        ]
            ARGV << [ "--one", "--two" ]
            Puppet.settings.stubs(:handlearg)

            @opt.expects(:each).multiple_yields(["--one", nil],["--two", nil])

            Puppet::Application.new(:test, options).parse_options
        end

        it "should call the method named handle_<option> if it exists" do
            options = [[ "--name", "-n", GetoptLong::NO_ARGUMENT ]]
            ARGV << [ "--name" ]
            @opt.stubs(:each).yields("--name", nil)

            app = Puppet::Application.new(:test, options)
            app.stubs(:respond_to).with(:handle_name).returns(true)

            app.expects(:handle_name)

            app.parse_options
        end

        it "should handle gracefully options containing '-'" do
            options = [[ "--name-with-dash", "-n", GetoptLong::NO_ARGUMENT ]]
            ARGV << [ "--name-with-dash" ]
            @opt.stubs(:each).yields("--name-with-dash", nil)

            app = Puppet::Application.new(:test, options)
            app.stubs(:respond_to).with(:handle_name_with_dash).returns(true)

            app.expects(:handle_name_with_dash)

            app.parse_options
        end

        it "should call the method named handle_<option> if it exists and pass argument" do
            options = [[ "--name", "-n", GetoptLong::REQUIRED_ARGUMENT ]]
            ARGV << [ "--name" ]
            arg = stub 'arg'
            @opt.stubs(:each).yields("--name", arg)

            app = Puppet::Application.new(:test, options)
            app.stubs(:respond_to).with(:name).returns(true)

            app.expects(:handle_name).with(arg)

            app.parse_options
        end

        describe "with 'no argument' options" do
            it "should store true in Application.options if present and no code blocks" do
                options = [[ "--one", "-o", GetoptLong::NO_ARGUMENT ]]
                ARGV << [ "--one" ]
                @opt.stubs(:each).yields("--one", nil)

                app = Puppet::Application.new(:test, options)
                app.options.expects(:[]=).with(:one, true)

                app.parse_options
            end
        end

        describe "with options with an argument" do
            it "should store the argument value in Application.options if present and no code blocks" do
                options = [[ "--one", "-o", GetoptLong::REQUIRED_ARGUMENT ]]
                argument = stub 'arg'
                ARGV << [ "--one" ]
                @opt.stubs(:each).yields("--one", argument)

                app = Puppet::Application.new(:test, options)
                app.options.expects(:[]=).with(:one, argument)

                app.parse_options
            end
        end

        describe "when using --help" do
            confine "requires RDoc" => Puppet.features.usage?

            it "should call RDoc::usage and exit" do
                options = [[ "--help", "-h", GetoptLong::REQUIRED_ARGUMENT ]]
                ARGV << [ "--help" ]
                @opt.stubs(:each).yields("--help", nil)
                app = Puppet::Application.new(:test, options)

                app.expects(:exit)
                RDoc.expects(:usage).returns(true)

                app.parse_options
            end

        end

        it "should pass unknown arguments to handle_unknown if it is defined" do
            options = []
            ARGV << [ "--not-handled" ]
            @opt.stubs(:each).yields("--not-handled", nil)
            app = Puppet::Application.new(:test, options)

            app.expects(:handle_unknown).with("--not-handled", nil).returns(true)

            app.parse_options
        end

        it "should pass back not directly or by handle_unknown handled arguments to Puppet.settings" do
            options = []
            ARGV << [ "--topuppet" ]
            @opt.stubs(:each).yields("--topuppet", nil)
            app = Puppet::Application.new(:test, options)
            app.stubs(:handle_unknown).with("--topuppet", nil).returns(false)

            Puppet.settings.expects(:handlearg).with("--topuppet", nil)

            app.parse_options
        end

        it "should pass back unknown arguments to Puppet.settings if no handle_unknown method exists" do
            options = []
            ARGV << [ "--topuppet" ]
            @opt.stubs(:each).yields("--topuppet", nil)
            app = Puppet::Application.new(:test, options)

            Puppet.settings.expects(:handlearg).with("--topuppet", nil)

            app.parse_options
        end

        it "should exit if getopt raise an error" do
            options = [[ "--pouet", "-p", GetoptLong::REQUIRED_ARGUMENT ]]
            ARGV << [ "--do-not-exist" ]
            @opt.stubs(:each).raises(GetoptLong::InvalidOption.new)
            $stderr.stubs(:puts)
            app = Puppet::Application.new(:test, options)

            app.expects(:exit)

            lambda { app.parse_options }.should_not raise_error
        end

    end

    describe "when calling default setup" do

        before :each do
            @app = Puppet::Application.new(:test)
            @app.stubs(:should_parse_config?).returns(false)
            @app.options.stubs(:[])
        end

        [ :debug, :verbose ].each do |level|
            it "should honor option #{level}" do
                @app.options.stubs(:[]).with(level).returns(true)
                Puppet::Util::Log.stubs(:newdestination)

                Puppet::Util::Log.expects(:level=).with(level == :verbose ? :info : :debug)

                @app.run_setup
            end
        end

        it "should honor setdest option" do
            @app.options.stubs(:[]).with(:setdest).returns(false)

            Puppet::Util::Log.expects(:newdestination).with(:syslog)

            @app.run_setup
        end

    end

    describe "when running" do

        before :each do
            @app = Puppet::Application.new(:test)
            @app.stubs(:run_preinit)
            @app.stubs(:run_setup)
            @app.stubs(:parse_options)
        end

        it "should call run_preinit" do
            @app.stubs(:run_command)

            @app.expects(:run_preinit)

            @app.run
        end

        it "should call parse_options" do
            @app.stubs(:run_command)

            @app.expects(:parse_options)

            @app.run
        end

        it "should call run_command" do

            @app.expects(:run_command)

            @app.run
        end

        it "should parse Puppet configuration if should_parse_config is called" do
            @app.stubs(:run_command)
            @app.should_parse_config

            Puppet.expects(:parse_config)

            @app.run
        end

        it "should not parse_option if should_not_parse_config is called" do
            @app.stubs(:run_command)
            @app.should_not_parse_config

            Puppet.expects(:parse_config).never

            @app.run
        end

        it "should parse Puppet configuration if needed" do
            @app.stubs(:run_command)
            @app.stubs(:should_parse_config?).returns(true)

            Puppet.expects(:parse_config)

            @app.run
        end

        it "should call the action matching what returned command" do
            @app.stubs(:get_command).returns(:backup)
            @app.stubs(:respond_to?).with(:backup).returns(true)

            @app.expects(:backup)

            @app.run
        end

        it "should call main as the default command" do
            @app.expects(:main)

            @app.run
        end

        it "should raise an error if no command can be called" do
            lambda { @app.run }.should raise_error(NotImplementedError)
        end

        it "should raise an error if dispatch returns no command" do
            @app.stubs(:get_command).returns(nil)

            lambda { @app.run }.should raise_error(NotImplementedError)
        end

        it "should raise an error if dispatch returns an invalid command" do
            @app.stubs(:get_command).returns(:this_function_doesnt_exist)

            lambda { @app.run }.should raise_error(NotImplementedError)
        end

    end

    describe "when metaprogramming" do

        before :each do
            @app = Puppet::Application.new(:test)
        end

        it "should create a new method with newcommand" do
            @app.command(:test) do
            end

            @app.should respond_to(:test)
        end

        it "should create a new method with newoption" do
            @app.option(:test) do
            end

            @app.should respond_to(:handle_test)
        end

        it "should create a method called run_setup with setup" do
            @app.setup do
            end

            @app.should respond_to(:run_setup)
        end

        it "should create a method called get_command with dispatch" do
            @app.dispatch do
            end

            @app.should respond_to(:get_command)
        end
    end
end