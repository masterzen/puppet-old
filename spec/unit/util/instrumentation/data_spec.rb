#!/usr/bin/env rspec

require 'spec_helper'
require 'matchers/json'
require 'puppet/util/instrumentation'
require 'puppet/util/instrumentation/data'

describe Puppet::Util::Instrumentation::Data do
  Puppet::Util::Instrumentation::Data

  before(:each) do
    @listener = stub 'listener', :name => "name"
    Puppet::Util::Instrumentation.stubs(:[]).with("name").returns(@listener)
  end

  it "should indirect instrumentation_data" do
    Puppet::Util::Instrumentation::Data.indirection.name.should == :instrumentation_data
  end

  it "should lookup the corresponding listener" do
    Puppet::Util::Instrumentation.expects(:[]).with("name").returns(@listener)
    Puppet::Util::Instrumentation::Data.new("name")
  end

  it "should return pson data" do
    data = Puppet::Util::Instrumentation::Data.new("name")
    @listener.stubs(:data).returns({ :this_is_data  => "here also" })
    data.should set_json_attribute('name').to("name")
    data.should set_json_attribute('this_is_data').to("here also")
  end

  it "should raise an error when deserializing from pson" do
    lambda { Puppet::Util::Instrumentation::Data.from_pson({}) }.should raise_error
  end
end