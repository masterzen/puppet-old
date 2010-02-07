#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_content/rest'
require 'puppet/file_serving/content'
require 'puppet/file_serving/content_stream'

describe "Puppet::Indirector::FileContent::Rest" do
    it "should be a sublcass of Puppet::Indirector::REST" do
        Puppet::Indirector::FileContent::Rest.superclass.should equal(Puppet::Indirector::REST)
    end

    describe "when finding" do
        before(:each) do
            @request = stub_everything 'request'
            Puppet::FileServing::Content.terminus_class = :rest
            @indirector = Puppet::Indirector::FileContent::Rest.new
            @indirector.stubs(:indirection2uri).with(@request).returns("/here")
            Puppet::Network::DeferredResponse.stubs(:new)
        end

        it "should return a Puppet::FileServing::ContentStream as model" do
            @indirector.find(@request).should be_instance_of(Puppet::FileServing::ContentStream)
        end

        it "should return a content stream wrapping a deferred response" do
            content = stub_everything 'content'
            Puppet::Network::DeferredResponse.expects(:new).returns content
            @indirector.find(@request).content.should == content
        end
    end
end
