#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::CollExpr do

    AST = Puppet::Parser::AST

    before :each do
        @scope = Puppet::Parser::Scope.new()        
    end
    
    describe "when evaluating with two operands" do
        before :each do
            @test1 = mock 'test1'
            @test1.expects(:safeevaluate).with(@scope).returns("test1")
            @test2 = mock 'test2'
            @test2.expects(:safeevaluate).with(@scope).returns("test2")
        end

        it "should evaluate both" do
            collexpr = AST::CollExpr.new(:test1 => @test1, :test2 => @test2, :oper=>"==")
            collexpr.evaluate(@scope)
        end

        it "should produce a textual representation and code of the expression" do
            collexpr = AST::CollExpr.new(:test1 => @test1, :test2 => @test2, :oper=>"==")
            result = collexpr.evaluate(@scope)
            result[0].should == "param_values.value = 'test2' and param_names.name = 'test1'"
            result[1].should be_an_instance_of(Proc)
        end

        it "should propagate expression type and form to child if expression themselves" do
            [@test1, @test2].each do |t| 
                t.expects(:is_a?).returns(true)
                t.expects(:form).returns(false)
                t.expects(:type).returns(false)
                t.expects(:type=)
                t.expects(:form=)
            end
        
            collexpr = AST::CollExpr.new(:test1 => @test1, :test2 => @test2, :oper=>"==", :form => true, :type => true)
            result = collexpr.evaluate(@scope)
        end

        describe "and when evaluating the produced code" do
            before :each do
                @resource = mock 'resource'
                @resource.expects(:[]).with("test1").at_least(1).returns("test2")
            end
        
            it "should evaluate like the original expression for ==" do
                collexpr = AST::CollExpr.new(:test1 => @test1, :test2 => @test2, :oper => "==")
                collexpr.evaluate(@scope)[1].call(@resource).should === (@resource["test1"] == "test2")
            end

            it "should evaluate like the original expression for !=" do
                collexpr = AST::CollExpr.new(:test1 => @test1, :test2 => @test2, :oper => "!=")
                collexpr.evaluate(@scope)[1].call(@resource).should === (@resource["test1"] != "test2")
            end
        end

        it "should warn if this is an exported collection containing parenthesis (unsupported)" do
            collexpr = AST::CollExpr.new(:test1 => @test1, :test2 => @test2, :oper=>"==", :parens => true, :form => :exported)
            Puppet.expects(:warning)
            collexpr.evaluate(@scope)
        end

        %w{and or}.each do |op|
            it "should raise an error if this is an exported collection with #{op} operator (unsupported)" do
                collexpr = AST::CollExpr.new(:test1 => @test1, :test2 => @test2, :oper=> op, :form => :exported)
                lambda { collexpr.evaluate(@scope) }.should raise_error(Puppet::ParseError)
            end
        end
    end
    
    it "should check for array member equality if resource parameter is an array for ==" do
        array = mock 'array', :safeevaluate => "array"
        test1 = mock 'test1'
        test1.expects(:safeevaluate).with(@scope).returns("test1")

        resource = mock 'resource'
        resource.expects(:[]).with("array").at_least(1).returns(["test1","test2","test3"])
        collexpr = AST::CollExpr.new(:test1 => array, :test2 => test1, :oper => "==")
        collexpr.evaluate(@scope)[1].call(resource).should be_true
    end

    it "should raise an error for invalid operator" do
        lambda { collexpr = AST::CollExpr.new(:oper=>">") }.should raise_error
    end

end