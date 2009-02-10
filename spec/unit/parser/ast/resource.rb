#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::Resource do

    ast = Puppet::Parser::AST

    before :each do
        @title = stub_everything 'title'
        @compiler = stub_everything 'compiler'
        @scope = Puppet::Parser::Scope.new(:compiler => @compiler)
        @param1 = stub_everything 'parameter', :is_a? => true
        @scope.stubs(:resource).returns(stub_everything)
        @params = ast::ASTArray.new( :children => [@param1])
        @resource = ast::Resource.new(:title => @title, :type => "Resource", :params => @params )
        @resource.stubs(:qualified_type).returns("Resource")
        Puppet::Parser::Resource.stubs(:new).returns(stub_everything)
    end

    it "should evaluate all its parameters" do

        @param1.expects(:safeevaluate).with(@scope)

        @resource.evaluate(@scope)
    end

    it "should evaluate its title" do

        @title.expects(:safeevaluate).with(@scope)

        @resource.evaluate(@scope)
    end

    it "should flatten the titles array" do
        titles = stub 'titles'
        title_array = stub 'title_array', :is_a? => true

        titles.stubs(:safeevaluate).with(@scope).returns(title_array)

        title_array.expects(:flatten).returns([])

        @resource.title = titles
        @resource.evaluate(@scope)
    end

    it "should create one resource objects per title" do
        titles = stub 'titles'

        titles.stubs(:safeevaluate).with(@scope).returns([ [:title1 , :title2], [:title3]])

        Puppet::Parser::Resource.expects(:new).with { |hash| not hash[:title].is_a?(Array) }

        @resource.title = titles
        @resource.evaluate(@scope)
    end

    it "should handover resources to the compiler" do
        resource = stub 'resource'
        titles = stub 'titles'
        title_array = stub 'title_array', :is_a? => true

        title_array.stubs(:flatten).returns([@title])
        titles.stubs(:safeevaluate).with(@scope).returns(title_array)
        Puppet::Parser::Resource.stubs(:new).returns(resource)

        @compiler.expects(:add_resource).with(@scope, resource)

        @resource.title = titles
        @resource.evaluate(@scope)
    end

    it "should return the newly created resources" do
        resource = stub 'resource'
        titles = stub 'titles'
        title_array = stub 'title_array', :is_a? => true

        title_array.stubs(:flatten).returns([@title])
        titles.stubs(:safeevaluate).with(@scope).returns(title_array)
        Puppet::Parser::Resource.stubs(:new).returns(resource)

        @compiler.stubs(:add_resource).with(resource)

        @resource.title = titles
        @resource.evaluate(@scope).should == [resource]
    end
end

