#!/usr/bin/env rspec

require 'spec_helper'

describe Puppet::Auth, "ssl rack authentication handler", :if => Puppet.features.rack? do

  before(:each) do
    Puppet[:auth] = "ssl"
  end

  def mk_req(uri, opts = {})
    env = Rack::MockRequest.env_for(uri, opts)
    Rack::Request.new(env)
  end

  describe "when authenticating a rack HTTP client" do
    before(:each) do
      @handler = Class.new do
        def self.name
          "Puppet::Network::HTTP::RackREST"
        end
        include Puppet::Auth::Handler
      end.new
      @ip = :foo
    end

    it "should set 'authenticated' to false if no certificate is present" do
      req = mk_req('/')
      @handler.authenticate(@ip, req)[0].should be_false
    end

    describe "with pre-validated certificates" do

      it "should retrieve the hostname by matching the certificate parameter" do
        Puppet[:ssl_client_header] = "myheader"
        req = mk_req('/', "myheader" => "/CN=host.domain.com")
        @handler.authenticate(@ip, req)[1].should == "host.domain.com"
      end

      it "should consider the host authenticated if the validity parameter contains 'SUCCESS'" do
        Puppet[:ssl_client_header] = "certheader"
        Puppet[:ssl_client_verify_header] = "myheader"
        req = mk_req('/', "myheader" => "SUCCESS", "certheader" => "/CN=host.domain.com")
        @handler.authenticate(@ip, req)[0].should be_true
      end

      it "should consider the host unauthenticated if the validity parameter does not contain 'SUCCESS'" do
        Puppet[:ssl_client_header] = "certheader"
        Puppet[:ssl_client_verify_header] = "myheader"
        req = mk_req('/', "myheader" => "whatever", "certheader" => "/CN=host.domain.com")
        @handler.authenticate(@ip, req)[0].should be_false
      end

      it "should consider the host unauthenticated if no certificate information is present" do
        Puppet[:ssl_client_header] = "certheader"
        Puppet[:ssl_client_verify_header] = "myheader"
        req = mk_req('/', "myheader" => nil, "certheader" => "/CN=host.domain.com")
        @handler.authenticate(@ip, req)[0].should be_false
      end

      it "should resolve the node name with an ip address look-up if no certificate is present" do
        Puppet[:ssl_client_header] = "myheader"
        req = mk_req('/', "myheader" => nil)
        @handler.expects(:resolve_node).returns("host.domain.com")
        @handler.authenticate(@ip, req)[1].should == "host.domain.com"
      end
    end
  end
end
