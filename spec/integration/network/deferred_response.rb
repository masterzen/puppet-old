#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/deferred_response'

describe Puppet::Network::DeferredResponse do
    before(:each) do
        @request = stub_everything 'request'
        @uri = stub_everything 'uri'
        @headers = stub_everything 'headers'

        @request = stub_everything 'request'
        @http = stub_everything 'http'
        @rest = stub_everything 'rest', :network => @http

        @response = stub_everything 'response'
        @http.stubs(:request_get).yields(@response)

        @stream = stub_everything 'stream', :response => @response
        @response.stubs(:read_body).multiple_yields("chunk1", "chunk2")
        @content = stub_everything 'content', :content => @stream

        @rest.stubs(:deserialize).returns(@content)

        @deferred = Puppet::Network::DeferredResponse.new(@request, @uri, @headers, @rest)
    end

    it "should pass chunks to the main thread" do
        @deferred.stream do |c|
            c.should match /^chunk\d/
        end
    end
end