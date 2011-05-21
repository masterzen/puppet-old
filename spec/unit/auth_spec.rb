#!/usr/bin/env rspec

require 'spec_helper'

require 'puppet/auth'

describe Puppet::Auth do
  before(:each) do
    Puppet[:auth] = "myauth"
  end

  %w{ client server }.each do |mode|
    describe "for #{mode}s" do
      it "should instance-load #{mode} auth types" do
        Puppet::Auth.instance_loader("#{mode}_auth".to_sym).should be_instance_of(Puppet::Util::Autoload)
      end

      it "should have a method for creating a new #{mode}" do
        Puppet::Auth.should respond_to("new_#{mode}".to_sym)
      end

      it "should have a method for retrieving auth #{mode} types by name" do
        Puppet::Auth.should respond_to(mode.to_sym)
      end
    end

    describe "when loading auth #{mode} types" do
      it "should use the instance loader to retrieve auth types" do
        Puppet::Auth.expects(:loaded_instance).with("#{mode}_auth".to_sym, "myauth")
        Puppet::Auth.send("#{mode}")
      end
    end

    describe "when registering auth #{mode} types" do
      it "should evaluate the supplied block as code for a class" do
        Puppet::Auth.expects(:genclass).returns(Class.new)
        Puppet::Auth.send("new_#{mode}", :testing) { }
      end

      it "should mangle the class name with the #{mode} prefix" do
        Puppet::Auth.expects(:genclass).with{ |n,o| o[:prefix] == mode.capitalize }.returns(Class.new)
        Puppet::Auth.send("new_#{mode}", :testing) { }
      end
    end
  end

  describe "when dealing with handler" do
    %w{webrick rack mongrel}.each do |network|
      describe "for #{network}" do
        it "should instance-load handler auth types" do
          Puppet::Auth.instance_loader("handler_#{network}_auth".to_sym).should be_instance_of(Puppet::Util::Autoload)
        end
      end

      describe "when loading" do
        it "should use the instance loader to retrieve the #{network} auth type" do
          Puppet::Auth.expects(:loaded_instance).with("handler_#{network}_auth".to_sym, "myauth")
          Puppet::Auth.handler(network)
        end
      end

      describe "when registering #{network} auth handler" do
        it "should evaluate the supplied block as code for a module" do
          Puppet::Auth.expects(:genmodule).returns(Module.new)
          Puppet::Auth.new_handler(:testing, network) { }
        end

        it "should mangle the class name with the #{network} prefix" do
          Puppet::Auth.expects(:genmodule).with{ |n,o| o[:prefix] == network.capitalize }.returns(Class.new)
          Puppet::Auth.new_handler(:testing, network) { }
        end
      end
    end

    it "should have a method for creating a new handler" do
      Puppet::Auth.should respond_to(:new_handler)
    end

    it "should have a method for retrieving auth handler types by name" do
      Puppet::Auth.should respond_to(:handler)
    end
  end
end
