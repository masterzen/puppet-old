#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::Not do
    before :each do
        @node = Puppet::Node.new "testnode"
        @parser = Puppet::Parser::Parser.new :environment => "development"
        @compiler = Puppet::Parser::Compiler.new(@node, @parser)

        @scope = @compiler.topscope
    end

    describe Puppet::Parser::AST::Not, "when parsing" do

        it "should parse if ! without error" do
            @parser.string="if ! false\n{\n#nothing\n}\n"
            lambda{ @parser.parse }.should_not raise_error
        end

    describe Puppet::Parser::AST::Not, "when evaluating" do

        it "should evaluate the if statements if not false" do
            @parser.string="if ! false\n{\n#nothing\n}\n"
            @parser.parse
        end

        it "should evaluate the else statements if not false" do
            @parser.string="if ! false\n{\n#nothing\n}\n"
            @parser.parse
        end

    end
end
