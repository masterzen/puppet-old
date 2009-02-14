#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/puppetca'

describe "PuppetCA" do
    before :each do
        @puppetca = Puppet::Application[:puppetca]
    end

    it "should ask Puppet::Application to parse Puppet configuration file" do
        @puppetca.should_parse_config?.should be_true
    end

    it "should declare a main command" do
        @puppetca.should respond_to(:main)
    end

    it "should declare a fallback for unknown options" do
        @puppetca.should respond_to(:handle_unknown)
    end

    it "should set log level to info with the --verbose option" do

        Puppet::Log.expects(:level=).with(:info)

        @puppetca.handle_verbose(0)
    end

    it "should set log level to debug with the --debug option" do

        Puppet::Log.expects(:level=).with(:debug)

        @puppetca.handle_debug(0)
    end

    it "should set mode to :destroy for --clean" do
        @puppetca.handle_clean(0)
        @puppetca.mode.should == :destroy
    end

    it "should set all to true for --all" do
        @puppetca.handle_all(0)
        @puppetca.all.should be_true
    end

    Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS.each do |method|
        it "should set mode to #{method} with option --#{method}" do
            @puppetca.handle_unknown("--#{method}", nil)

            @puppetca.mode.should == method
        end
    end

    it "should set mode to nil for an option not in the list of known CertificateAuthority option" do
        @puppetca.handle_unknown("--dontknowme", nil)

        @puppetca.mode.should be_nil
    end

    describe "during setup" do

        before :each do
            Puppet::Log.stubs(:newdestination)
            Puppet::SSL::Host.stubs(:ca_location=)
            Puppet::SSL::CertificateAuthority.stubs(:new)
        end

        it "should set console as the log destination" do
            Puppet::Log.expects(:newdestination).with(:console)

            @puppetca.run_setup
        end

        it "should print puppet config if asked to in Puppet config" do
            @puppetca.stubs(:exit)
            Puppet.settings.stubs(:print_configs?).returns(true)

            Puppet.settings.expects(:print_configs)

            @puppetca.run_setup
        end

        it "should exit after printing puppet config if asked to in Puppet config" do
            Puppet.settings.stubs(:print_configs?).returns(true)

            lambda { @puppetca.run_setup }.should raise_error(SystemExit)
        end

        it "should create a new certificate authority" do
            Puppet::SSL::CertificateAuthority.expects(:new)

            @puppetca.run_setup
        end
    end

    describe "when running" do
        before :each do
            @puppetca.all = false
            @ca = stub_everything 'ca'
            @puppetca.ca = @ca
            ARGV.stubs(:collect).returns([])
        end

        it "should delegate to the CertificateAuthority" do
            @ca.expects(:apply)

            @puppetca.main
        end

        it "should delegate with :all if option --all was given" do
            @puppetca.handle_all(0)

            @ca.expects(:apply).with { |mode,to| to[:to] == :all }

            @puppetca.main
        end

        it "should delegate to ca.apply with the hosts given on command line" do
            ARGV.stubs(:collect).returns(["host"])

            @ca.expects(:apply).with { |mode,to| to[:to] == ["host"]}

            @puppetca.main
        end

        it "should delegate to ca.apply with current set mode" do
            @puppetca.mode = "currentmode"
            ARGV.stubs(:collect).returns(["host"])

            @ca.expects(:apply).with { |mode,to| mode == "currentmode" }

            @puppetca.main
        end

    end
end