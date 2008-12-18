#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/checksum/rest'

describe Puppet::Checksum::Rest do
    it "should be a subclass of Puppet::Indirector::REST" do
        Puppet::Checksum::Rest.superclass.should equal(Puppet::Indirector::REST)
    end
end
