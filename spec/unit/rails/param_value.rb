#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe "Puppet::Storeconfigs::Rails::ParamValue" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?

    def column(name, type)
        ActiveRecord::ConnectionAdapters::Column.new(name, nil, type, false)
    end

    before do
        require 'puppet/storeconfigs/rails/param_value'

        name = stub 'param_name', :name => "foo"

        # Stub this so we don't need access to the DB.
        Puppet::Storeconfigs::Rails::ParamValue.stubs(:columns).returns([column("value", "string")])
        Puppet::Storeconfigs::Rails::ParamName.stubs(:find_or_create_by_name).returns(name)
    end

    describe "when creating initial parameter values" do
        it "should return an array of hashes" do
            Puppet::Storeconfigs::Rails::ParamValue.from_parser_param(:myparam, %w{a b})[0].should be_instance_of(Hash)
        end

        it "should return hashes for each value with the parameter name set as the ParamName instance" do
            name = stub 'param_name', :name => "foo"
            Puppet::Storeconfigs::Rails::ParamName.expects(:find_or_create_by_name).returns(name)

            result = Puppet::Storeconfigs::Rails::ParamValue.from_parser_param(:myparam, "a")[0]
            result[:value].should == "a"
            result[:param_name].should == name
        end

        it "should return an array of hashes even when only one parameter is provided" do
            Puppet::Storeconfigs::Rails::ParamValue.from_parser_param(:myparam, "a")[0].should be_instance_of(Hash)
        end

        it "should convert all arguments into strings" do
            Puppet::Storeconfigs::Rails::ParamValue.from_parser_param(:myparam, 50)[0][:value].should == "50"
        end

        it "should not convert Resource References into strings" do
            ref = Puppet::Resource::Reference.new(:file, "/file")
            Puppet::Storeconfigs::Rails::ParamValue.from_parser_param(:myparam, ref)[0][:value].should == ref
        end
    end
end
