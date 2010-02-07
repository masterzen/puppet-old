#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/deferred_response'

describe Puppet::Network::DeferredResponse do
    before(:each) do
        @request = stub_everything 'request'
        @uri = stub_everything 'uri'
        @headers = stub_everything 'headers'

        @request = stub_everything 'request'
        @http = stub_everything 'http', :request_get => @request
        @rest = stub_everything 'rest', :network => @http

        @chunk_queue = stub_everything 'chunk_queue'
        SizedQueue.expects(:new).returns(@chunk_queue)

        @got_response = stub_everything 'got_response'
        ConditionVariable.stubs(:new).returns(@got_response)

        @mutex = stub_everything 'mutex'
        @mutex.stubs(:synchronize).yields
        Mutex.expects(:new).returns(@mutex)

        @deferred = Puppet::Network::DeferredResponse.new(@request, @uri, @headers, @rest)
    end

    it "should be a 'stream'" do
        @deferred.should be_stream
    end

    it "should be possible to set a checksum" do
        @deferred.should be_respond_to(:checksum=)
    end

    describe "when getting length" do
        before(:each) do
            @response = stub_everything 'response'
            @deferred.response = @response
            @deferred.stubs(:start_request)
        end

        it "should start the network request" do
            @deferred.expects(:start_request)
            @deferred.length
        end

        it "should return the response content length" do
            @response.expects(:content_length).returns 10
            @deferred.length.should == 10
        end
    end

    describe "when streaming" do
        before(:each) do
            @deferred.stubs(:start_request)
        end

        it "should start the network request" do
            @deferred.expects(:start_request)
            @deferred.stream
        end

        it "should fetch one chunk from the chunk queue" do
            @chunk_queue.expects(:pop).twice.returns("chunk", nil)
            @deferred.stream { |c| }
        end

        it "should fetch all chunks from the chunk queue until nil" do
            @chunk_queue.expects(:pop).times(3).returns("chunk1", "chunk2", nil)
            @deferred.stream { |c|
                c.should match /^chunk\d/
            }
        end

        it "should give the chunk to the current checksum stream" do
            checksum = stub_everything 'checksum'
            @deferred.checksum = checksum

            @chunk_queue.expects(:pop).twice.returns("chunk", nil)
            checksum.expects(:update).with("chunk")

            @deferred.stream { |c| }
        end

        it "should yield the chunks to the given block" do
            @chunk_queue.expects(:pop).twice.returns("chunk", nil)

            @deferred.stream { |c|
                c.should == "chunk"
            }
        end

        it "should return the checksum" do
            checksum = stub_everything 'checksum'
            @deferred.checksum = checksum

            @deferred.stream.should == checksum
        end
    end

    describe "when issueing the network request" do
        before(:each) do
            Thread.stubs(:new).yields(nil)
            @stream = stub_everything 'stream'
            @content = stub_everything 'content', :content => @stream
            @response = stub_everything 'response'
            @content.stubs(:response).returns(@response)
        end

        it "should return early if the request has already been started" do
            @deferred.expects(:request_started?).returns(true)
            @rest.expects(:network).never
            @deferred.start_request
        end

        it "should launch the request in a new Thread" do
            Thread.expects(:new).yields
            @rest.expects(:network).with(@request).returns(@http)
            @http.expects(:request_get).with(@uri, @headers)
            @deferred.start_request
        end

        describe "and the network thread" do
            before(:each) do
                Thread.expects(:new).yields
                @rest.stubs(:network).with(@request).returns(@http)
                @rest.stubs(:deserialize).returns(@content)
                @http.stubs(:request_get).with(@uri, @headers).yields(@response)
                @deferred.stubs(:stream_response)
            end

            it "should let everyone know the request has started" do
                @deferred.start_request
                @deferred.request_started?.should be true
            end

            it "should signal other threads that the response is ready" do
                @got_response.expects(:signal)
                @deferred.start_request
            end

            it "should store the current response" do
                @deferred.start_request
                @deferred.response.should == @response
            end

            it "should deserialize the response" do
                @rest.expects(:deserialize).with(@response).returns(@content)
                @deferred.start_request
            end

            it "should stream the response content" do
                @deferred.expects(:stream_response).with(@stream)
                @deferred.start_request
            end
        end

        describe "and the other thread" do
            it "should finally wait the request to be started" do
                @got_response.expects(:wait)
                @deferred.start_request
            end
        end

        describe "when streaming the response content" do
            it "should put each chunk in the chunk queue" do
                @response.expects(:read_body).multiple_yields("chunk1","chunk2")
                @chunk_queue.expects(:<<).with("chunk1").then.with("chunk2")
                @deferred.stream_response(@content)
            end

            it "should enqueue nil at the end" do
                @chunk_queue.expects(:<<).with(nil)
                @deferred.stream_response(@content)
            end
        end
    end

end