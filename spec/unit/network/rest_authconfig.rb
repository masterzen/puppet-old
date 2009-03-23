#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/rest_authconfig'

describe Puppet::Network::RestAuthConfig do
    before :each do
        FileTest.stubs(:exists?).returns(true)
        File.stubs(:stat).returns(stub 'stat', :ctime => :now)
        Time.stubs(:now).returns :now

        @authconfig = Puppet::Network::RestAuthConfig.new("dummy", false)
        @authconfig.stubs(:read)

        @acl = stub_everything 'rights'
        @authconfig.rights = @acl

        @request = stub 'request'
        @request.stubs(:indirection_name).returns("path")
        @request.stubs(:key).returns("to/resource")
        @request.stubs(:ip).returns("127.0.0.1")
        @request.stubs(:node).returns("me")
        @request.stubs(:method).returns(:save)
    end

    it "should use the puppet default rest authorization file" do
        Puppet.expects(:[]).with(:rest_authconfig).returns("dummy")

        Puppet::Network::RestAuthConfig.new(nil, false)
    end

    it "should read the config file when needed" do
        @authconfig.expects(:read)

        @authconfig.allowed?(@request)
    end

    it "should ask for authorization to the ACL subsystem" do
        @acl.expects(:allowed?).with("/path/to/resource", "me", "127.0.0.1", :save)

        @authconfig.allowed?(@request)
    end

    describe "when defining an acl with mk_acl" do
        it "should create a new right for each default acl" do
            @acl.expects(:newright).with(:path, :type => :path)
            @authconfig.mk_acl(:path)
        end

        it "should allow everyone for each default right" do
            @acl.expects(:allow).with(:path, "*")
            @authconfig.mk_acl(:path)
        end

        it "should restrict the ACL to a method" do
            @acl.expects(:method).with(:path, :method)
            @authconfig.mk_acl(:path, :method)
        end
    end

    describe "when parsing the configuration file" do
        it "should check for missing ACL after reading the authconfig file" do
            File.stubs(:open)

            @authconfig.expects(:insert_missing_acl)

            @authconfig.parse()
        end
    end

    [ "/facts", "/report", "/catalog", "/file"].each do |acl|
        it "should insert #{acl} if not present" do
            @authconfig.rights.stubs(:[]).returns(true)
            @authconfig.rights.stubs(:[]).with(acl).returns(nil)

            @authconfig.expects(:mk_acl).with { |a,m| a == acl }

            @authconfig.insert_missing_acl
        end

        it "should not insert #{acl} if present" do
            @authconfig.rights.stubs(:[]).returns(true)
            @authconfig.rights.stubs(:[]).with(acl).returns(true)

            @authconfig.expects(:mk_acl).never

            @authconfig.insert_missing_acl
        end
    end

    it "should create default ACL entries if no file have been read" do
        Puppet::Network::RestAuthConfig.any_instance.stubs(:exists?).returns(false)

        Puppet::Network::RestAuthConfig.any_instance.expects(:mk_default_acls)

        Puppet::Network::RestAuthConfig.main
    end

    describe "when adding default ACLs" do

        [
            { :acl => "/facts", :method => [:save, :find] },
            { :acl => "/catalog", :method => :find },
            { :acl => "/report", :method => :save },
            { :acl => "/file" },
        ].each do |acl|
            it "should create a default right for #{acl[:acl]}" do
                @authconfig.stubs(:mk_acl)
                @authconfig.expects(:mk_acl).with(acl[:acl], acl[:method])
                @authconfig.mk_default_acls
            end
        end

        it "should create a last catch-all deny all rule" do
            @authconfig.stubs(:mk_acl)
            @acl.expects(:newright).with("/", :type => :path)
            @authconfig.mk_default_acls
        end

    end

end
