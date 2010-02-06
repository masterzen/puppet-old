#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/formats'

class PsonIntTest
    attr_accessor :string
    def ==(other)
        other.class == self.class and string == other.string
    end

    def self.from_pson(data)
        new(data[0])
    end

    def initialize(string)
        @string = string
    end

    def to_pson_data_hash
        {
            'type' => self.class.name,
            'data' => [@string]
        }
    end

    def to_pson(*args)
        to_pson_data_hash.to_pson(*args)
    end

    def self.canonical_order(s)
        s.gsub(/\{"data":\[(.*?)\],"type":"PsonIntTest"\}/,'{"type":"PsonIntTest","data":[\1]}')
    end

end

describe Puppet::Network::FormatHandler.format(:s) do
    before do
        @format = Puppet::Network::FormatHandler.format(:s)
    end

    it "should support certificates" do
        @format.should be_supported(Puppet::SSL::Certificate)
    end

    it "should not support catalogs" do
        @format.should_not be_supported(Puppet::Resource::Catalog)
    end
end

describe Puppet::Network::FormatHandler.format(:pson) do
    describe "when pson is absent" do
        confine "'pson' library is present" => (! Puppet.features.pson?)

        before do
            @pson = Puppet::Network::FormatHandler.format(:pson)
        end

        it "should not be suitable" do
            @pson.should_not be_suitable
        end
    end

    describe "when pson is available" do
        confine "Missing 'pson' library" => Puppet.features.pson?

        before do
            @pson = Puppet::Network::FormatHandler.format(:pson)
        end

        it "should be able to render an instance to pson" do
            instance = PsonIntTest.new("foo")
            PsonIntTest.canonical_order(@pson.render(instance)).should == PsonIntTest.canonical_order('{"type":"PsonIntTest","data":["foo"]}' )
        end

        it "should be able to render arrays to pson" do
            @pson.render([1,2]).should == '[1,2]'
        end

        it "should be able to render arrays containing hashes to pson" do
            @pson.render([{"one"=>1},{"two"=>2}]).should == '[{"one":1},{"two":2}]'
        end

        it "should be able to render multiple instances to pson" do
            Puppet.features.add(:pson, :libs => ["pson"])

            one = PsonIntTest.new("one")
            two = PsonIntTest.new("two")

            PsonIntTest.canonical_order(@pson.render([one,two])).should == PsonIntTest.canonical_order('[{"type":"PsonIntTest","data":["one"]},{"type":"PsonIntTest","data":["two"]}]')
        end

        it "should be able to intern pson into an instance" do
            @pson.intern(PsonIntTest, '{"type":"PsonIntTest","data":["foo"]}').should == PsonIntTest.new("foo")
        end

        it "should be able to intern pson with no class information into an instance" do
            @pson.intern(PsonIntTest, '["foo"]').should == PsonIntTest.new("foo")
        end

        it "should be able to intern multiple instances from pson" do
            @pson.intern_multiple(PsonIntTest, '[{"type": "PsonIntTest", "data": ["one"]},{"type": "PsonIntTest", "data": ["two"]}]').should == [
                PsonIntTest.new("one"), PsonIntTest.new("two")
            ]
        end

        it "should be able to intern multiple instances from pson with no class information" do
            @pson.intern_multiple(PsonIntTest, '[["one"],["two"]]').should == [
                PsonIntTest.new("one"), PsonIntTest.new("two")
            ]
        end
    end
end

describe Puppet::Network::FormatHandler.format(:yajl) do
    describe "when yajl is absent" do
        confine "'yajl' library is present" => (! Puppet.features.yajl?)

        before do
            @yajl = Puppet::Network::FormatHandler.format(:yajl)
        end

        it "should not be suitable" do
            @yajl.should_not be_suitable
        end

        it "should not be supported" do
            @yajl.should_not be_supported
        end
    end

    describe "when yajl is available" do
        confine "Missing 'yajl' library" => Puppet.features.yajl?

        before do
            @yajl = Puppet::Network::FormatHandler.format(:yajl)
        end

        it "should be able to render an instance to json" do
            instance = PsonIntTest.new("foo")
            PsonIntTest.canonical_order(@yajl.render(instance)).should == PsonIntTest.canonical_order('{"type":"PsonIntTest","data":["foo"]}' )
        end

        it "should be able to render arrays to json" do
            @yajl.render([1,2]).should == '[1,2]'
        end

        it "should be able to render arrays containing hashes to json" do
            @yajl.render([{"one"=>1},{"two"=>2}]).should == '[{"one":1},{"two":2}]'
        end

        it "should be able to render multiple instances to json" do
            Puppet.features.add(:yajl, :libs => %w{yajl})

            one = PsonIntTest.new("one")
            two = PsonIntTest.new("two")

            PsonIntTest.canonical_order(@yajl.render([one,two])).should == PsonIntTest.canonical_order('[{"type":"PsonIntTest","data":["one"]},{"type":"PsonIntTest","data":["two"]}]')
        end

        it "should be able to intern a stream" do
            content = stub 'stream', :stream? => true
            content.expects(:stream).multiple_yields('{"type":"PsonIntTest",', '"data":["foo"]}')
            @yajl.intern(PsonIntTest, content).should == PsonIntTest.new("foo")
        end

        it "should be able to intern json into an instance" do
            @yajl.intern(PsonIntTest, '{"type":"PsonIntTest","data":["foo"]}').should == PsonIntTest.new("foo")
        end

        it "should be able to intern json with no class information into an instance" do
            @yajl.intern(PsonIntTest, '["foo"]').should == PsonIntTest.new("foo")
        end

        it "should be able to intern multiple instances from json" do
            @yajl.intern_multiple(PsonIntTest, '[{"type": "PsonIntTest", "data": ["one"]},{"type": "PsonIntTest", "data": ["two"]}]').should == [
                PsonIntTest.new("one"), PsonIntTest.new("two")
            ]
        end

        it "should be able to intern multiple instances from json with no class information" do
            @yajl.intern_multiple(PsonIntTest, '[["one"],["two"]]').should == [
                PsonIntTest.new("one"), PsonIntTest.new("two")
            ]
        end
    end
end
