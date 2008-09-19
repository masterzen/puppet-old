#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::BooleanOperator do
    before :each do
        @scope = Puppet::Parser::Scope.new()
        @true_ast = Puppet::Parser::AST::Boolean.new( :value => true)
        @false_ast = Puppet::Parser::AST::Boolean.new( :value => false)
    end

    it "should evaluate both branches" do
        lval = stub "lval"
        lval.expects(:safeevaluate).with(@scope)
        rval = stub "rval"
        rval.expects(:safeevaluate).with(@scope)
        
        operator = Puppet::Parser::AST::BooleanOperator.new :rval => rval, :operator => "or", :lval => lval
        operator.evaluate(@scope)
    end

    it "should return true for true OR false" do
        operator = Puppet::Parser::AST::BooleanOperator.new :rval => @true_ast, :operator => "or", :lval => @false_ast
        operator.evaluate(@scope).should == true
    end

    it "should return false for true AND false" do
        operator = Puppet::Parser::AST::BooleanOperator.new(:rval => @true_ast, :operator => "and", :lval => @false_ast )
        operator.evaluate(@scope).should == false
    end

end
