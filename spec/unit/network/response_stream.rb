#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/response_stream'

describe Puppet::Network::ResponseStream do
    before(:each) do
        @content = stub_everything 'content'
        @stream = Puppet::Network::ResponseStream.new(@content)
    end

    it "should identify itself as a stream if the underlying content is an http response" do
        @content.expects(:is_a?).with(Net::HTTPResponse).returns(true)
        @stream.should be_stream
    end

    it "should not identify itself as a stream if the underlying content is not an http response" do
        @content.expects(:is_a?).with(Net::HTTPResponse).returns(false)
        @stream.should_not be_stream
    end

    it "should be able to return content length" do
        @stream.should respond_to(:length)
    end

    it "should be able to stream content" do
        @stream.should respond_to(:stream)
    end

    describe "when asking for content length" do
        it "should return the content-length header if it is a stream" do
            @stream.stubs(:stream?).returns(true)
            @content.expects(:content_length).returns 10
            @stream.length.should == 10
        end

        it "should return the string length otherwise" do
            @content.expects(:length).returns 10
            @stream.length.should == 10
        end
    end

    describe "when streaming" do
        it "should yield the block to the response read_body method if it is a stream" do
            @stream.stubs(:stream?).returns(true)
            @content.expects(:read_body).yields("chunk")
            @stream.stream do |chunk|
                chunk.should == "chunk"
            end
        end

        it "should yield the full body if it is not a stream" do
            @content.expects(:body).returns("body")
            @stream.stream do |chunk|
                chunk.should == "body"
            end
        end
    end
end