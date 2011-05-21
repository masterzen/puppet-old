#!/usr/bin/env rspec

require 'spec_helper'

require 'puppet/auth'
require 'puppet/auth/handler'
require 'puppet/network/http'

describe Puppet::Auth::Handler do
  describe "when included" do
    it "should include the correct sub-handler" do
      handler = Class.new() do
        def self.name
          "Puppet::Network::HTTP::MongrelREST"
        end
      end
      handler.send(:include, Puppet::Auth::Handler)

      handler.should be_include(Puppet::Auth::MongrelSsl)
    end
  end

  describe "when resolving node" do
    before do
      @handler = Class.new do
        def self.name
          "Puppet::Network::HTTP::MongrelREST"
        end
        include Puppet::Auth::Handler
      end.new
    end

    it "should use a look-up from the ip address" do
      Resolv.expects(:getname).with("1.2.3.4").returns("host.domain.com")

      @handler.resolve_node("1.2.3.4")
    end

    it "should return the look-up result" do
      Resolv.stubs(:getname).with("1.2.3.4").returns("host.domain.com")

      @handler.resolve_node("1.2.3.4").should == "host.domain.com"
    end

    it "should return the ip address if resolving fails" do
      Resolv.stubs(:getname).with("1.2.3.4").raises(RuntimeError, "no such host")

      @handler.resolve_node("1.2.3.4").should == "1.2.3.4"
    end
  end
end
