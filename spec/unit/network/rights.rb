#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/rights'

describe Puppet::Network::Rights do
    before do
        @right = Puppet::Network::Rights.new
    end

    [:allow, :deny].each do |m|
        it "should have a #{m} method" do
            @right.should respond_to(m)
        end

        describe "when using #{m}" do
            it "should delegate to the correct acl" do
                acl = stub 'acl'
                @right.stubs(:right).returns(acl)

                acl.expects(m).with("me")

                @right.send(m, 'thisacl', "me")
            end
        end
    end

    it "should throw an error if no types are passed at creation" do
        lambda { @right.newright("name", {}) }.should raise_error
    end

    describe "when creating new namespace ACLs" do

        it "should throw an error if the ACL already exists" do
            @right.newright("name", :type => :name)

            lambda { @right.newright("name", :type => :name)}.should raise_error
        end

        it "should create a new ACL with the correct name" do
            @right.newright("name", :type => :name)

            @right["name"].name.should == :name
        end

        it "should create an ACL of type Puppet::Network::AuthStore" do
            @right.newright("name", :type => :name)

            @right["name"].should be_a_kind_of(Puppet::Network::AuthStore)
        end

        it "should create an ACL with a shortname" do
            @right.newright("name", :type => :name)

            @right["name"].shortname.should == "n"
        end
    end

    describe "when creating new path ACLs" do
        it "should throw an error if the ACL already exists" do
            @right.newright("/name", :type => :path)

            lambda { @right.newright("/name", :type => :path)}.should raise_error
        end

        it "should throw an error if the acl uri path is not absolute" do
            lambda { @right.newright("name", :type => :path)}.should raise_error
        end

        it "should create a new ACL with the correct path" do
            @right.newright("/name", :type => :path)

            @right["/name"].should_not be_nil
        end

        it "should create an ACL of type Puppet::Network::AuthStore" do
            @right.newright("/name", :type => :path)

            @right["/name"].should be_a_kind_of(Puppet::Network::AuthStore)
        end
    end

    describe "when checking ACLs existance" do
        it "should return false if there is no matching rights" do
            @right.include?("name").should be_false
        end

        it "should return true if a namespace rights exists" do
            @right.newright("name")

            @right.include?("name").should be_true
        end

        it "should return false if no matching namespace rights exists" do
            @right.newright("name")

            @right.include?("notname").should be_false
        end

        it "should return true if a path rights exists" do
            @right.newright("/name")

            @right.include?("/name").should be_true
        end

        it "should return false if no matching path rights exists" do
            @right.newright("/name")

            @right.include?("/differentname").should be_false
        end
    end

    describe "when checking if right is allowed" do
        before :each do
            @right.stubs(:right).returns(nil)

            @pathacl = stub 'pathacl'
            Puppet::Network::Rights::PathRight.stubs(:new).returns(@pathacl)
        end

        it "should first check namespace rights" do
            acl = stub 'acl'
            Puppet::Network::Rights::Right.stubs(:new).returns(acl)

            @right.newright("namespace")
            acl.expects(:allowed?).with(:args)

            @right.allowed?("namespace", :args)
        end

        it "should then check for path rights if no namespace matches" do
            acl = stub 'acl'
            @right.stubs(:right).with("namespace").returns(acl)

            acl.expects(:allowed?).with(:args).never
            @right.newright("/path/to/there", :type => :path)

            @pathacl.stubs(:match).returns(true)
            @pathacl.expects(:allowed?)

            @right.allowed?("/path/to/there", :args)
        end

        describe "with path acls" do
            before :each do
                @long_acl = stub 'longpathacl', :name => "/path/to/there", :length => 14
                Puppet::Network::Rights::PathRight.stubs(:new).with("/path/to/there", "/").returns(@long_acl)

                @short_acl = stub 'shortpathacl', :name => "/path/to", :length => 8
                Puppet::Network::Rights::PathRight.stubs(:new).with("/path/to", "/").returns(@short_acl)

            end

            it "should select the longest match" do
                @right.newright("/path/to/there", :type => :path)
                @right.newright("/path/to", :type => :path)

                @long_acl.stubs(:match).returns(true)
                @short_acl.stubs(:match).returns(true)

                @long_acl.expects(:allowed?).returns(true)
                @short_acl.expects(:allowed?).never

                @right.allowed?("/path/to/there/and/there", :args)
            end

            it "should select the longest match that doesn't return :dunno" do
                @right.newright("/path/to/there", :type => :path)
                @right.newright("/path/to", :type => :path)

                @long_acl.stubs(:match).returns(true)
                @short_acl.stubs(:match).returns(true)

                @long_acl.expects(:allowed?).returns(:dunno)
                @short_acl.expects(:allowed?)

                @right.allowed?("/path/to/there/and/there", :args)
            end

            it "should not select an ACL that doesn't match" do
                @right.newright("/path/to/there", :type => :path)
                @right.newright("/path/to", :type => :path)

                @long_acl.stubs(:match).returns(false)
                @short_acl.stubs(:match).returns(true)

                @long_acl.expects(:allowed?).never
                @short_acl.expects(:allowed?)

                @right.allowed?("/path/to/there/and/there", :args)
            end

            it "should return the result of the acl" do
                @right.newright("/path/to/there", :type => :path)

                @long_acl.stubs(:match).returns(true)
                @long_acl.stubs(:allowed?).returns(:returned)

                @right.allowed?("/path/to/there/and/there", :args).should == :returned
            end

        end

    end

    describe Puppet::Network::Rights::PathRight do
        before :each do
            @acl = Puppet::Network::Rights::PathRight.new("/path", "/")
        end

        it "should say it's a path ACL" do
            @acl.should be_a_path
        end

        it "should match up to its path length" do
            @acl.match("/path/that/works").should be_true
        end

        it "should match up to its path length" do
            @acl.match("/paththatalsoworks").should be_true
        end

        it "should return false if no match" do
            @acl.match("/notpath").should be_false
        end

        it "should allow all rest methods by default" do
            @acl.methods.should == Puppet::Network::Rights::PathRight::ALL
        end

        it "should allow modification of the methods filters" do
            @acl.method(:save)

            @acl.methods.should == [:save]
        end

        it "should stack methods filters" do
            @acl.method(:save)
            @acl.method(:destroy)

            @acl.methods.should == [:save, :destroy]
        end

        it "should raise an error if the method is already filtered" do
            @acl.method(:save)

            lambda { @acl.method(:save) }.should raise_error
        end

        describe "when checking right authorization" do
            it "should return :dunno if this right doesn't apply" do
                @acl.method(:destroy)

                @acl.allowed?("me","127.0.0.1", :save).should == :dunno
            end

            # mocha doesn't allow testing super...
            # it "should delegate to the AuthStore for the result" do
            #     @acl.method(:save)
            # 
            #     @acl.expects(:allowed?).with("me","127.0.0.1")
            # 
            #     @acl.allowed?("me","127.0.0.1", :save)
            # end
        end
    end

end
