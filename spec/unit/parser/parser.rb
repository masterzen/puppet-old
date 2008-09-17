#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser do
    
    AST = Puppet::Parser::AST
    
    before :each do
        @parser = Puppet::Parser::Parser.new :environment => "development"
        @true_ast = AST::Boolean.new :value => true
    end
    
    # describe Puppet::Parser, "when parsing if" do
    #     it "not, it should create the correct ast objects" do
    #         AST::Not.expects(:new).with { |h| h[:value].is_a?(AST::Boolean) }
    #         @parser.parse("if ! true { $var = 1 }")
    #     
    #     end
    # 
    #     it "boolean operation, it should create the correct ast objects" do
    #         AST::BooleanOperator.expects(:new).with { 
    #             |h| h[:rval].is_a?(AST::Boolean) and h[:lval].is_a?(AST::Boolean) and h[:operator]=="or"
    #         }
    #         @parser.parse("if true or true { $var = 1 }")
    #     
    #     end
    # 
        it "comparison operation, it should create the correct ast objects" do
             AST::ComparisonOperator.expects(:new).with { 
                 |h| h[:lval].is_a?(AST::Name) and h[:rval].is_a?(AST::Name) and h[:operator]=="<"
             }
             @parser.parse("if 1 < 2 { $var = 1 }")
         
         end
     # 
    # end
    
    describe Puppet::Parser, "when parsing if complex expressions" do
         it "should create an ast tree" do
             
             AST::ComparisonOperator.expects(:new).with { 
                 |h| h[:rval].is_a?(AST::Name) and h[:lval].is_a?(AST::Name) and h[:operator]==">"
             }
             AST::ComparisonOperator.expects(:new).with { 
                 |h| h[:rval].is_a?(AST::Name) and h[:lval].is_a?(AST::Name) and h[:operator]=="=="
             }
             AST::BooleanOperator.expects(:new).with {
                 |h| h[:rval].is_a?(AST::Boolean) and h[:lval].is_a?(AST::Boolean) and h[:operator]=="and"                
             }
             @parser.parse("if (1 > 2) and (1 == 2) { $var = 1 }")
         end
     end
 end