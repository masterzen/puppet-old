#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'ostruct'
require 'puppet/util/network_device'

describe Puppet::Util::NetworkDevice do

  before(:each) do
    @device = OpenStruct.new(:name => "name", :provider => "test")
  end

  class Puppet::Util::NetworkDevice::Test::Device
    def initialize(device)
    end
  end

  describe "when initializing the remote network device singleton" do
    it "should load the network device code" do
      Puppet::Util::NetworkDevice.expects(:require)
      Puppet::Util::NetworkDevice.init(@device)
    end

    it "should create a network device instance" do
      Puppet::Util::NetworkDevice.stubs(:require)
      Puppet::Util::NetworkDevice::Test::Device.expects(:new)
      Puppet::Util::NetworkDevice.init(@device)
    end

    it "should raise an error if the remote device instance can't be created" do
      Puppet::Util::NetworkDevice.stubs(:require).raises("error")
      lambda { Puppet::Util::NetworkDevice.init(@device) }.should raise_error
    end

    it "should let caller to access the singleton device" do
      device = stub 'device'
      Puppet::Util::NetworkDevice.stubs(:require)
      Puppet::Util::NetworkDevice::Test::Device.expects(:new).returns(device)
      Puppet::Util::NetworkDevice.init(@device)

      Puppet::Util::NetworkDevice.current.should == device
    end
  end
end