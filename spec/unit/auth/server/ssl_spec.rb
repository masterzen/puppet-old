#!/usr/bin/env rspec

require 'spec_helper'

require 'puppet/auth'
require 'puppet/ssl/host'

describe Puppet::Auth, "ssl master" do
  before(:each) do
    Puppet[:auth] = "ssl"
  end

  describe "when initializing" do
    before(:each) do
      Puppet::SSL::Host.stubs(:localhost)
      Puppet::SSL::CertificateAuthority.stubs(:instance)
      Puppet::SSL::CertificateAuthority.stubs(:ca?)
      Puppet::SSL::Host.stubs(:ca_location=)
      Puppet.settings.stubs(:use)
    end

    it "should use ssl" do
      Puppet.settings.expects(:use).with(:ssl)
      Puppet::Auth.server.init
    end

    describe "with no ca" do
      it "should set the ca_location to none" do
        Puppet::SSL::Host.expects(:ca_location=).with(:none)

        Puppet::Auth.server.init
      end
    end

    describe "with a ca configured" do
      before :each do
        Puppet::SSL::CertificateAuthority.stubs(:ca?).returns(true)
      end

      it "should set the ca_location to local" do
        Puppet::SSL::Host.expects(:ca_location=).with(:local)

        Puppet::Auth.server.init
      end

      it "should tell Puppet.settings to use :ca category" do
        Puppet.settings.expects(:use).with(:ca)

        Puppet::Auth.server.init
      end

      it "should instantiate the CertificateAuthority singleton" do
        Puppet::SSL::CertificateAuthority.expects(:instance)

        Puppet::Auth.server.init
      end
    end

    it "should generate a SSL cert for localhost" do
      Puppet::SSL::Host.expects(:localhost)

      Puppet::Auth.server.init
    end

    it "should make sure to *only* hit the CA for data" do
      Puppet::SSL::CertificateAuthority.stubs(:ca?).returns(true)

      Puppet::SSL::Host.expects(:ca_location=).with(:only)

      Puppet::Auth.server.init
    end
  end
end
