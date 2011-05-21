#!/usr/bin/env rspec

require 'spec_helper'

require 'puppet/auth'
require 'puppet/ssl/host'

describe Puppet::Auth, "ssl client" do
  before(:each) do
    Puppet[:auth] = "ssl"

    @host = stub_everything 'host'
    Puppet::SSL::Host.stubs(:new).returns(@host)
  end

  describe "when initializing" do
    it "should use ssl" do
      Puppet.settings.expects(:use).with(:ssl)
      Puppet::Auth.client.init({})
    end

    it "should install a remote ca location" do
      Puppet::SSL::Host.expects(:ca_location=).with(:remote)

      Puppet::Auth.client.init({})
    end

    it "should install a none ca location in fingerprint mode" do
      Puppet::SSL::Host.expects(:ca_location=).with(:none)

      Puppet::Auth.client.init({:fingerprint => true})
    end
  end

  describe "when setting up" do
    it "should set waitforcert to 0 with --onetime and if --waitforcert wasn't given" do
      Puppet[:onetime] = true
      @host.expects(:wait_for_cert).with(0)
      Puppet::Auth.client.setup({})
    end

    it "should use supplied waitforcert when --onetime is specified" do
      Puppet[:onetime] = true
      @host.expects(:wait_for_cert).with(60)
      Puppet::Auth.client.setup({:waitforcert => 60})
    end

    it "should use a default value for waitforcert when --onetime and --waitforcert are not specified" do
      @host.expects(:wait_for_cert).with(120)
      Puppet::Auth.client.setup({})
    end

    it "should wait for a certificate" do
      @host.expects(:wait_for_cert).with(123)
      Puppet::Auth.client.setup({:waitforcert => 123})
    end

    it "should not wait for a certificate in fingerprint mode" do
      @host.expects(:wait_for_cert).never
      Puppet::Auth.client.setup({:waitforcert => 123, :fingerprint => true})
    end
  end

  describe "when setting ssl for the http client" do
    before do
      @client = stub_everything 'client'
      FileTest.stubs(:exists?).returns(false)
    end

    it "should enable ssl on the http instance" do
      @client.expects(:use_ssl=).with(true)
      Puppet::Auth.client.setup_http_client(@client)
    end

    describe "when adding certificate information to http instances" do
      before do
        @http = mock 'http'
        [:cert_store=, :verify_mode=, :ca_file=, :cert=, :key=, :use_ssl=].each { |m| @http.stubs(m) }
        @store = stub 'store'

        @cert = stub 'cert', :content => "real_cert"
        @key = stub 'key', :content => "real_key"
        @host = stub 'host', :certificate => @cert, :key => @key, :ssl_store => @store

        Puppet[:confdir] = "/sometthing/else"
        Puppet[:hostcert] = "/host/cert"
        Puppet[:localcacert] = "/local/ca/cert"

        FileTest.stubs(:exist?).with("/host/cert").returns true
        FileTest.stubs(:exist?).with("/local/ca/cert").returns true

        Puppet::Auth::client.stubs(:ssl_host).returns @host
      end

      after do
        Puppet.settings.clear
      end

      it "should do nothing if no host certificate is on disk" do
        FileTest.expects(:exist?).with("/host/cert").returns false
        @http.expects(:cert=).never
        Puppet::Auth.client.setup_http_client(@http)
      end

      it "should do nothing if no local certificate is on disk" do
        FileTest.expects(:exist?).with("/local/ca/cert").returns false
        @http.expects(:cert=).never
        Puppet::Auth.client.setup_http_client(@http)
      end

      it "should add a certificate store from the ssl host" do
        @http.expects(:cert_store=).with(@store)

        Puppet::Auth.client.setup_http_client(@http)
      end

      it "should add the client certificate" do
        @http.expects(:cert=).with("real_cert")

        Puppet::Auth.client.setup_http_client(@http)
      end

      it "should add the client key" do
        @http.expects(:key=).with("real_key")

        Puppet::Auth.client.setup_http_client(@http)
      end

      it "should set the verify mode to OpenSSL::SSL::VERIFY_PEER" do
        @http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

        Puppet::Auth.client.setup_http_client(@http)
      end

      it "should set the ca file" do
        FileTest.stubs(:exist?).with(Puppet[:hostcert]).returns true

        Puppet[:localcacert] = "/ca/cert/file"
        FileTest.stubs(:exist?).with("/ca/cert/file").returns true
        @http.expects(:ca_file=).with("/ca/cert/file")

        Puppet::Auth.client.setup_http_client(@http)
      end
    end
  end
end
