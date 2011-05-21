#!/usr/bin/env rspec

require 'spec_helper'

describe Puppet::Auth, "ssl mongrel authentication handler", :if => Puppet.features.mongrel? do

  before(:each) do
    Puppet[:auth] = "ssl"
  end

  describe "when authenticating a mongrel HTTP client" do
    before(:each) do
      @handler = Class.new do
        def self.name
          "Puppet::Network::HTTP::MongrelREST"
        end
        include Puppet::Auth::Handler
      end.new
      @ip = :foo
    end

    it "should retrieve the hostname by matching the certificate parameter" do
      Puppet[:ssl_client_header] = "myheader"
      params = {"myheader" => "/CN=host.domain.com"}
      @handler.authenticate(@ip, params)[1].should == "host.domain.com"
    end

    it "should consider the host authenticated if the validity parameter contains 'SUCCESS'" do
      Puppet[:ssl_client_header] = "certheader"
      Puppet[:ssl_client_verify_header] = "myheader"
      params = {"myheader" => "SUCCESS", "certheader" => "/CN=host.domain.com"}
      @handler.authenticate(@ip, params)[0].should be_true
    end

    it "should consider the host unauthenticated if the validity parameter does not contain 'SUCCESS'" do
      Puppet[:ssl_client_header] = "certheader"
      Puppet[:ssl_client_verify_header] = "myheader"
      params = {"myheader" => "whatever", "certheader" => "/CN=host.domain.com"}
      @handler.authenticate(@ip, params)[0].should be_false
    end

    it "should consider the host unauthenticated if no certificate information is present" do
      Puppet[:ssl_client_header] = "certheader"
      Puppet[:ssl_client_verify_header] = "myheader"
      params = {"myheader" => nil, "certheader" => "SUCCESS"}
      @handler.authenticate(@ip, params)[0].should be_false
    end

    it "should resolve the node name with an ip address look-up if no certificate is present" do
      Puppet[:ssl_client_header] = "myheader"
      params = {"myheader" => nil}
      @handler.expects(:resolve_node).returns("host.domain.com")
      @handler.authenticate(@ip, params)[1].should == "host.domain.com"
    end
  end
end
