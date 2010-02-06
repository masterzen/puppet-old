
require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/util/checksum_stream'

describe Puppet::Util::ChecksumStream do

    before(:each) do
        @digest = stub 'digest'
        @digest.stubs(:reset).returns(@digest)
        @sum = Puppet::Util::ChecksumStream.new(@digest)
    end

    it "should add to the digest when update" do
        @digest.expects(:<<).with("content")
        @sum.update("content")
    end

    it "should produce the final checksum" do
        @digest.expects(:hexdigest).returns("DEADBEEF")
        @sum.checksum.should == "DEADBEEF"
    end
end