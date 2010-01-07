#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe "The require function" do
    before :each do
        @node = Puppet::Node.new("mynode")
        @compiler = Puppet::Parser::Compiler.new(@node)

        @compiler.send(:evaluate_main)
        @compiler.catalog.client_version = "0.25"
        @scope = @compiler.topscope
        # preload our functions
        Puppet::Parser::Functions.function(:include)
        Puppet::Parser::Functions.function(:require)
    end

    it "should add a dependency between the 'required' class and our class" do
        @compiler.known_resource_types.add Puppet::Parser::ResourceType.new(:hostclass, "requiredclass")

        @scope.function_require("requiredclass")
        @scope.resource["require"].should_not be_nil
        ref = @scope.resource["require"]
        ref.type.should == "Class"
        ref.title.should == "requiredclass"
    end
end
