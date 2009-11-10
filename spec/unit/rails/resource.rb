#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe "Puppet::Storeconfigs::Rails::Resource" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?

    def column(name, type)
        ActiveRecord::ConnectionAdapters::Column.new(name, nil, type, false)
    end

    before do
        require 'puppet/storeconfigs/rails/resource'

        # Stub this so we don't need access to the DB.
        Puppet::Storeconfigs::Rails::Resource.stubs(:columns).returns([column("title", "string"), column("restype", "string"), column("exported", "boolean")])
    end

    describe "when creating initial resource arguments" do
        it "should set the restype to the resource's type" do
            Puppet::Storeconfigs::Rails::Resource.rails_resource_initial_args(Puppet::Resource.new(:file, "/file"))[:restype].should == "File"
        end

        it "should set the title to the resource's title" do
            Puppet::Storeconfigs::Rails::Resource.rails_resource_initial_args(Puppet::Resource.new(:file, "/file"))[:title].should == "/file"
        end

        it "should set the line to the resource's line if one is available" do
            resource = Puppet::Resource.new(:file, "/file")
            resource.line = 50

            Puppet::Storeconfigs::Rails::Resource.rails_resource_initial_args(resource)[:line].should == 50
        end

        it "should set 'exported' to true of the resource is exported" do
            resource = Puppet::Resource.new(:file, "/file")
            resource.exported = true

            Puppet::Storeconfigs::Rails::Resource.rails_resource_initial_args(resource)[:exported].should be_true
        end

        it "should set 'exported' to false of the resource is not exported" do
            resource = Puppet::Resource.new(:file, "/file")
            resource.exported = false

            Puppet::Storeconfigs::Rails::Resource.rails_resource_initial_args(resource)[:exported].should be_false

            resource = Puppet::Resource.new(:file, "/file")
            resource.exported = nil

            Puppet::Storeconfigs::Rails::Resource.rails_resource_initial_args(resource)[:exported].should be_false
        end
    end

    describe "when merging in a parser resource" do
        before do
            @parser = mock 'parser resource'

            @resource = Puppet::Storeconfigs::Rails::Resource.new
            [:merge_attributes, :merge_parameters, :merge_tags, :save].each { |m| @resource.stubs(m) }
        end

        it "should merge the attributes" do
            @resource.expects(:merge_attributes).with(@parser)

            @resource.merge_parser_resource(@parser)
        end

        it "should merge the parameters" do
            @resource.expects(:merge_parameters).with(@parser)

            @resource.merge_parser_resource(@parser)
        end

        it "should merge the tags" do
            @resource.expects(:merge_tags).with(@parser)

            @resource.merge_parser_resource(@parser)
        end

        it "should save itself" do
            @resource.expects(:save)

            @resource.merge_parser_resource(@parser)
        end
    end
end
