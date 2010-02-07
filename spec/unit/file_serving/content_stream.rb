#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/content_stream'

describe Puppet::FileServing::ContentStream do
    it "should should be a subclass of Content" do
        Puppet::FileServing::ContentStream.superclass.should equal(Puppet::FileServing::Content)
    end

    it "should be able to create a content instance" do
        Puppet::FileServing::ContentStream.should respond_to(:create)
    end

    it "should return the content itself when converting from raw" do
        content = stub 'content'
        Puppet::FileServing::ContentStream.from_raw(content).should == content
    end

    it "should create an instance with a fake file name and correct content when converting from raw" do
        instance = mock 'instance'
        Puppet::FileServing::ContentStream.expects(:new).with("/this/is/a/fake/path").returns instance

        instance.expects(:content=).with "foo/bar"

        Puppet::FileServing::ContentStream.create("foo/bar").should equal(instance)
    end
end
