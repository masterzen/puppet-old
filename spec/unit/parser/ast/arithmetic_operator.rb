#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::ArithmeticOperator do
    before :each do
        @scope = Puppet::Parser::Scope.new()
        @one = stub 'lval', :safeevaluate => 1
        @two = stub 'lval', :safeevaluate => 2
    end

    it "should evaluate both branches" do
        lval = stub "lval"
        lval.expects(:safeevaluate).with(@scope).returns(1)
        rval = stub "rval"
        rval.expects(:safeevaluate).with(@scope).returns(2)
        
        operator = Puppet::Parser::AST::ArithmeticOperator.new :rval => rval, :operator => "+", :lval => lval
        operator.evaluate(@scope)
    end

    it "should fail for an unknown operator" do
        lambda { operator = Puppet::Parser::AST::ArithmeticOperator.new :lval => @one, :operator => "%", :rval => @two }.should raise_error
    end

    it "should return 3 for 1 + 2" do
        operator = Puppet::Parser::AST::ArithmeticOperator.new :lval => @one, :operator => "+", :rval => @two
        operator.evaluate(@scope).should == 3
    end

    it "should return -1 for 1 - 2" do
        operator = Puppet::Parser::AST::ArithmeticOperator.new :lval => @one, :operator => "-", :rval => @two
        operator.evaluate(@scope).should == -1
    end

    it "should return 0 for 1 / 2" do
        operator = Puppet::Parser::AST::ArithmeticOperator.new :lval => @one, :operator => "/", :rval => @two
        operator.evaluate(@scope).should == 0
    end

    it "should return 4 for 2 * 2" do
        operator = Puppet::Parser::AST::ArithmeticOperator.new :lval => @two, :operator => "*", :rval => @two
        operator.evaluate(@scope).should == 4
    end

    it "should return 8 for 2 << 2" do
        operator = Puppet::Parser::AST::ArithmeticOperator.new :lval => @two, :operator => "<<", :rval => @two
        operator.evaluate(@scope).should == 8
    end

    it "should return 1 for 2 >> 1" do
        operator = Puppet::Parser::AST::ArithmeticOperator.new :lval => @two, :operator => ">>", :rval => @one
        operator.evaluate(@scope).should == 1
    end

    it "should work even with numbers embedded in strings" do
        two = stub 'two', :safevealuate => "2"
        one = stub 'one', :safevealuate => "1"
        operator = Puppet::Parser::AST::ArithmeticOperator.new :lval => two, :operator => "+", :rval => one
        operator.evaluate(@scope).should == 3
    end

    it "should work even with floats" do
        two = stub 'two', :safevealuate => 2.53
        one = stub 'one', :safevealuate => 1.80
        operator = Puppet::Parser::AST::ArithmeticOperator.new :lval => two, :operator => "+", :rval => one
        operator.evaluate(@scope).should == 4.33
    end


    it "should work for variables too" do
        @scope.expects(:lookupvar).with("one").returns(1)
        @scope.expects(:lookupvar).with("two").returns(2)
        one = Puppet::Parser::AST::Variable.new( :value => "one" )
        two = Puppet::Parser::AST::Variable.new( :value => "two" )
        
        operator = Puppet::Parser::AST::ArithmeticOperator.new :lval => one, :operator => "+", :rval => two
        operator.evaluate(@scope).should == 3
    end

end
