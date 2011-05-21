#!/usr/bin/env rspec

require 'spec_helper'

describe Puppet::Auth, "ssl webrick authentication handler" do
  before(:each) do
    Puppet[:auth] = "ssl"
  end

  describe "when configuring webrick ssl" do
    before do
      @key = stub 'key', :content => "mykey"
      @cert = stub 'cert', :content => "mycert"
      @host = stub 'host', :key => @key, :certificate => @cert, :name => "yay", :ssl_store => "mystore"

      Puppet::SSL::Certificate.indirection.stubs(:find).with('ca').returns @cert

      Puppet::SSL::Host.stubs(:localhost).returns @host
    end

    it "should use the key from the localhost SSL::Host instance" do
      Puppet::SSL::Host.expects(:localhost).returns @host
      @host.expects(:key).returns @key

      Puppet::Auth.handler(:webrick).setup[:SSLPrivateKey].should == "mykey"
    end

    it "should configure the certificate" do
      Puppet::Auth.handler(:webrick).setup[:SSLCertificate].should == "mycert"
    end

    it "should fail if no CA certificate can be found" do
      Puppet::SSL::Certificate.indirection.stubs(:find).with('ca').returns nil

      lambda { Puppet::Auth.handler(:webrick).setup }.should raise_error(Puppet::Error)
    end

    it "should specify the path to the CA certificate" do
      Puppet[:hostcrl] = 'false'
      Puppet[:localcacert] = '/ca/crt'

      Puppet::Auth.handler(:webrick).setup[:SSLCACertificateFile].should == "/ca/crt"
    end

    it "should start ssl immediately" do
      Puppet::Auth.handler(:webrick).setup[:SSLStartImmediately].should be_true
    end

    it "should enable ssl" do
      Puppet::Auth.handler(:webrick).setup[:SSLEnable].should be_true
    end

    it "should configure the verification method as 'OpenSSL::SSL::VERIFY_PEER'" do
      Puppet::Auth.handler(:webrick).setup[:SSLVerifyClient].should == OpenSSL::SSL::VERIFY_PEER
    end

    it "should add an x509 store" do
      Puppet[:hostcrl] = '/my/crl'

      @host.expects(:ssl_store).returns "mystore"

      Puppet::Auth.handler(:webrick).setup[:SSLCertificateStore].should == "mystore"
    end

    it "should set the certificate name to 'nil'" do
      Puppet::Auth.handler(:webrick).setup[:SSLCertName].should be_nil
    end
  end

  describe "when authenticating a webrick HTTP client" do
    before(:each) do
      @handler = Class.new do
        def self.name
          "Puppet::Network::HTTP::WEBrickREST"
        end
        include Puppet::Auth::Handler
      end.new
      @ip = :foo
      @request = stub('webrick http request', :query => {}, :peeraddr => %w{eh boo host ip}, :client_cert => nil)
    end

    it "should set 'authenticated' to true if a certificate is present" do
      cert = stub 'cert', :subject => [%w{CN host.domain.com}]
      @request.stubs(:client_cert).returns cert
      @handler.authenticate(@ip, @request)[0].should be_true
    end

    it "should set 'authenticated' to false if no certificate is present" do
      @request.stubs(:client_cert).returns nil
      @handler.authenticate(@ip, @request)[0].should be_false
    end

    it "should pass the client's certificate name to model method if a certificate is present" do
      cert = stub 'cert', :subject => [%w{CN host.domain.com}]
      @request.stubs(:client_cert).returns cert
      @handler.authenticate(@ip, @request)[1].should == "host.domain.com"
    end

    it "should resolve the node name with an ip address look-up if no certificate is present" do
      @request.stubs(:client_cert).returns nil

      @handler.expects(:resolve_node).with(:foo).returns(:resolved_node)

      @handler.authenticate(@ip, @request)[1].should == :resolved_node
    end
  end
end
