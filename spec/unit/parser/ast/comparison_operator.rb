#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::ComparisonOperator do
    before :each do
        @scope = Puppet::Parser::Scope.new()
        @one = Puppet::Parser::AST::FlatString.new( :value => 1 )
        @two = Puppet::Parser::AST::FlatString.new( :value => 2 )
    end

    it "should evaluate both branches" do
        lval = stub "lval"
        lval.expects(:safeevaluate).with(@scope)
        rval = stub "rval"
        rval.expects(:safeevaluate).with(@scope)
        
        operator = Puppet::Parser::AST::ComparisonOperator.new :lval => lval, :operator => "==", :rval => rval
        operator.evaluate(@scope)
    end

    it "should fail for an unknown operator" do
        lambda { operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @one, :operator => "or", :rval => @two }.should raise_error
    end

    it "should return true for 1 < 2" do
        operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @one, :operator => "<", :rval => @two
        operator.evaluate(@scope).should == true
    end

    it "should return false for 1 > 2" do
        operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @one, :operator => ">", :rval => @two
        operator.evaluate(@scope).should == false
    end

    it "should return true for 1 <= 2" do
        operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @one, :operator => "<=", :rval => @two
        operator.evaluate(@scope).should == true
    end

    it "should return true for 2 <= 2" do
        operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @two, :operator => "<=", :rval => @two
        operator.evaluate(@scope).should == true
    end

    it "should return true for 2 == 2" do
        operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @two, :operator => "==", :rval => @two
        operator.evaluate(@scope).should == true
    end

    it "should return false for 2 != 2" do
        operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @two, :operator => "!=", :rval => @two
        operator.evaluate(@scope).should == false
    end

    it "should work for variables too" do
        @scope.expects(:lookupvar).with("one").returns(1)
        @scope.expects(:lookupvar).with("two").returns(2)
        one = Puppet::Parser::AST::Variable.new( :value => "one" )
        two = Puppet::Parser::AST::Variable.new( :value => "two" )
        
        operator = Puppet::Parser::AST::ComparisonOperator.new :lval => one, :operator => "<", :rval => two
        operator.evaluate(@scope).should == true
    end

end
