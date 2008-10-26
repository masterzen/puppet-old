#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/parser/ast'

describe Puppet::Parser::AST do

    it "should have a doc accessor" do
        ast = Puppet::Parser::AST.new({})
        ast.should be_respond_to(:doc)
    end

    describe "when initializing" do
        it "should store the doc argument" do
            ast = Puppet::Parser::AST.new({ :doc => "documentation" })
            ast.doc.should == "documentation"
        end
    end

end