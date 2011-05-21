#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2007-11-26.
#  Copyright (c) 2007. All rights reserved.

require 'spec_helper'
require 'puppet/network/http_pool'

describe Puppet::Network::HttpPool do
  after do
    Puppet::Util::Cacher.expire
    Puppet::Network::HttpPool.clear_http_instances
  end

  it "should have keep-alive disabled" do
    Puppet::Network::HttpPool::HTTP_KEEP_ALIVE.should be_false
  end

  describe "when managing http instances" do
    def stub_settings(settings)
      settings.each do |param, value|
        Puppet.settings.stubs(:value).with(param).returns(value)
      end
    end

    before do
      # All of the cert stuff is tested elsewhere
      @auth = stub_everything 'auth'
      Puppet::Auth.stubs(:client).returns(@auth)
    end

    it "should return an http instance created with the passed host and port" do
      http = stub 'http', :use_ssl= => nil, :read_timeout= => nil, :open_timeout= => nil, :started? => false
      Net::HTTP.expects(:new).with("me", 54321, nil, nil).returns(http)
      Puppet::Network::HttpPool.http_instance("me", 54321).http.should equal(http)
    end

    it "should set the read timeout" do
      Puppet::Network::HttpPool.http_instance("me", 54321).read_timeout.should == 120
    end

    it "should set the open timeout" do
      Puppet::Network::HttpPool.http_instance("me", 54321).open_timeout.should == 120
    end

    it "should create the http instance with the proxy host and port set if the http_proxy is not set to 'none'" do
      stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
      Puppet::Network::HttpPool.http_instance("me", 54321).open_timeout.should == 120
    end

    describe "and http keep-alive is enabled" do
      before do
        Puppet::Network::HttpPool.stubs(:keep_alive?).returns true
      end

      it "should cache http instances" do
        stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.http_instance("me", 54321).http.should equal(old.http)
      end

      it "should have a mechanism for getting a new http instance instead of the cached instance" do
        stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.http_instance("me", 54321, true).http.should_not equal(old.http)
      end

      it "should close existing, open connections when requesting a new connection" do
        stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        old.http.expects(:started?).returns(true)
        old.http.expects(:finish)
        Puppet::Network::HttpPool.http_instance("me", 54321, true)
      end

      it "should have a mechanism for clearing the http cache" do
        stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.http_instance("me", 54321).http.should equal(old.http)
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.clear_http_instances
        Puppet::Network::HttpPool.http_instance("me", 54321).http.should_not equal(old.http)
      end

      it "should close open http connections when clearing the cache" do
        stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
        one = Puppet::Network::HttpPool.http_instance("me", 54321)
        one.http.expects(:started?).returns(true)
        one.http.expects(:finish).returns(true)
        Puppet::Network::HttpPool.clear_http_instances
      end

      it "should not close unopened http connections when clearing the cache" do
        stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
        one = Puppet::Network::HttpPool.http_instance("me", 54321)
        one.http.expects(:started?).returns(false)
        one.http.expects(:finish).never
        Puppet::Network::HttpPool.clear_http_instances
      end
    end

    describe "and http keep-alive is disabled" do
      before do
        Puppet::Network::HttpPool.stubs(:keep_alive?).returns false
      end

      it "should not cache http instances" do
        stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.http_instance("me", 54321).should_not equal(old)
      end
    end

    it "should set up certificate information when creating http instances" do
      @auth.with { |i| i.is_a?(Net::HTTP) }
      Puppet::Network::HttpPool.http_instance("one", "two")
    end

    after do
      Puppet::Network::HttpPool.clear_http_instances
    end
  end
end
