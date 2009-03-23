#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/authconfig'

describe Puppet::Network::AuthConfig do
    before do
        @rights = stubs 'rights'
        Puppet::Network::Rights.stubs(:new).returns(@rights)
        @rights.stubs(:each).returns([])

        FileTest.stubs(:exists?).returns(true)
        File.stubs(:stat).returns(stub 'stat', :ctime => :now)
        Time.stubs(:now).returns :now

        @authconfig = Puppet::Network::AuthConfig.new("dummy", false)
    end

    describe "when initializing" do
        before :each do
            Puppet::Network::AuthConfig.any_instance.stubs(:read)
        end

        it "should use the authconfig default pathname if none provided" do
            Puppet.expects(:[]).with(:authconfig).returns("dummy")

            Puppet::Network::AuthConfig.new
        end

        it "should raise an error if no file is defined in fine" do
            Puppet.stubs(:[]).with(:authconfig).returns(nil)

            lambda { Puppet::Network::AuthConfig.new }.should raise_error(Puppet::DevError)
        end

        it "should read and parse the file if parsenow is true" do
            Puppet::Network::AuthConfig.any_instance.expects(:read)

            Puppet::Network::AuthConfig.new("dummy", true)
        end

    end

    describe "when checking authorization" do
        before :each do
            @authconfig.stubs(:read)
            @call = stub 'call', :intern => "name"
            @handler = stub 'handler', :intern => "handler"
            @method = stub_everything 'method'
            @request = stub 'request', :call => @call, :handler => @handler, :method => @method, :name => "me", :ip => "1.2.3.4"
        end

        it "should attempt to read the authconfig file" do
            @rights.stubs(:include?)

            @authconfig.expects(:read)

            @authconfig.allowed?(@request)
        end

        it "should use a name right if it exists" do
            right = stub 'right'

            @rights.stubs(:include?).with("name").returns(true)
            @rights.stubs(:[]).with("name").returns(right)

            right.expects(:allowed?).with("me", "1.2.3.4")

            @authconfig.allowed?(@request)
        end

        it "should use a namespace right otherwise" do
            right = stub 'right'

            @rights.stubs(:include?).with("name").returns(false)
            @rights.stubs(:include?).with("handler").returns(true)
            @rights.stubs(:[]).with("handler").returns(right)

            right.expects(:allowed?).with("me", "1.2.3.4")

            @authconfig.allowed?(@request)
        end

        it "should return whatever the found rights returns" do
            right = stub 'right'

            @rights.stubs(:include?).with("name").returns(true)
            @rights.stubs(:[]).with("name").returns(right)

            right.stubs(:allowed?).with("me", "1.2.3.4").returns(:returned)

            @authconfig.allowed?(@request).should == :returned
        end

    end

    describe "when parsing authconfig file" do
        before :each do
            @fd = stub 'fd'
            File.stubs(:open).yields(@fd)
            @rights.stubs(:include?).returns(false)
            @rights.stubs(:[])
        end

        it "should skip comments" do
            @fd.stubs(:each).yields('  # comment')

            @rights.expects(:newright).never

            @authconfig.read
        end

        it "should skip blank lines" do
            @fd.stubs(:each).yields('  ')

            @rights.expects(:newright).never

            @authconfig.read
        end

        it "should throw an error if the current namespace right already exist" do
            @fd.stubs(:each).yields('[puppetca]')

            @rights.stubs(:include?).with("puppetca").returns(true)

            lambda { @authconfig.read }.should raise_error
        end

        it "should throw an error if the current path right already exist" do
            @fd.stubs(:each).yields('path /hello')

            @rights.stubs(:include?).with("/hello").returns(true)

            lambda { @authconfig.read }.should raise_error
        end

        it "should create a new right for found namespaces" do
            @fd.stubs(:each).yields('[puppetca]')

            @rights.expects(:newright).with("puppetca", {:type => :name})

            @authconfig.read
        end

        it "should create a new right for each found namespace line" do
            @fd.stubs(:each).multiple_yields('[puppetca]', '[fileserver]')

            @rights.expects(:newright).with("puppetca", {:type => :name})
            @rights.expects(:newright).with("fileserver", {:type => :name})

            @authconfig.read
        end

        it "should create a new right for each found path line" do
            @fd.stubs(:each).multiple_yields('path /certificates')

            @rights.expects(:newright).with("/certificates", {:type => :path})

            @authconfig.read
        end

        it "should create an allow ACE on each subsequent allow" do
            acl = stub 'acl', :info

            @fd.stubs(:each).multiple_yields('[puppetca]', 'allow 127.0.0.1')
            @rights.stubs(:newright).with("puppetca", {:type => :name})
            @rights.stubs(:[]).returns(acl)

            acl.expects(:allow).with('127.0.0.1')

            @authconfig.read
        end

        it "should create a deny ACE on each subsequent deny" do
            acl = stub 'acl', :info

            @fd.stubs(:each).multiple_yields('[puppetca]', 'deny 127.0.0.1')
            @rights.stubs(:newright).with("puppetca", {:type => :name})
            @rights.stubs(:[]).returns(acl)

            acl.expects(:deny).with('127.0.0.1')

            @authconfig.read
        end

        it "should inform the current ACL if we get the method directive" do
            acl = stub 'acl', :info
            acl.stubs(:path?).returns(true)

            @fd.stubs(:each).multiple_yields('path /certificates', 'method search,find')
            @rights.stubs(:newright).with("/certificates", {:type => :path})
            @rights.stubs(:[]).returns(acl)

            acl.expects(:method).with('search')
            acl.expects(:method).with('find')

            @authconfig.read
        end

        it "should raise an error if method is used in a right different than a path one" do
            acl = stub 'acl', :info, :path? => false

            @fd.stubs(:each).multiple_yields('[puppetca]', 'method search,find')
            @rights.stubs(:newright).with("puppetca", {:type => :path})
            @rights.stubs(:[]).returns(acl)

            lambda { @authconfig.read }.should raise_error
        end

    end

end
