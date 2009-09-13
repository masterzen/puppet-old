#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/storeconfigs'

class Puppet::Storeconfigs::ForTestingPurposes
end

describe Puppet::Storeconfigs do

    it "should find the correct source from the source symbol" do
        Puppet::Storeconfigs.source = :for_testing_purposes

        Puppet::Storeconfigs.source.should == Puppet::Storeconfigs::ForTestingPurposes
    end

    it "should allow access to the source name" do
        Puppet::Storeconfigs.source = :for_testing_purposes
        Puppet::Storeconfigs.source_name.should == :for_testing_purposes
    end

    [:init, :teardown, :migrate].each do |m|
        it "should proxy #{m} to the source" do
            source = stub_everything 'source'
            Puppet::Storeconfigs.stubs(:source).returns(source)
            Puppet::Storeconfigs.stubs(:source_name).returns(:dummy)
            Puppet.features.stubs(:dummy?).returns(true)

            source.expects(m)

            Puppet::Storeconfigs.send(m)
        end

        it "should raise an error if feature is not available when proxying #{m}" do
            Puppet.features.stubs(:dummy?).returns(false)
            lambda { Puppet::Storeconfigs.send(m) }.should raise_error
        end
    end

end