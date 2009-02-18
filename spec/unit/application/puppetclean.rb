#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/puppetclean'

describe "puppetclean" do
    before :each do
        @puppetclean = Puppet::Application[:puppetclean]
    end

    it "should not ask Puppet::Application to parse Puppet configuration file" do
        @puppetclean.should_not be_should_parse_config
    end

    it "should declare a main command" do
        @puppetclean.should respond_to(:main)
    end

    describe "when handling options" do
        [:debug, :verbose, :unexport].each do |option|
            it "should declare handle_#{option} method" do
                @puppetclean.should respond_to("handle_#{option}".to_sym)
            end

            it "should store argument value when calling handle_#{option}" do
                @puppetclean.options.expects(:[]=).with(option, 'arg')
                @puppetclean.send("handle_#{option}".to_sym, 'arg')
            end
        end
    end

    describe "during setup" do
        before :each do
            Puppet::Log.stubs(:newdestination)
            Puppet::Log.stubs(:level=)
            Puppet.stubs(:parse_config)
            Puppet.stubs(:[]=).with(:name, "puppetmasterd")
            Puppet::Node::Facts.stubs(:terminus_class=)
            Puppet::Node.stubs(:cache_class=)
        end

        it "should set console as the log destination" do
            Puppet::Log.expects(:newdestination).with(:console)

            @puppetclean.run_setup
        end

        it "should parse puppet configuration" do
            Puppet.expects(:parse_config)

            @puppetclean.run_setup
        end

        it "should change application name to get puppetmasterd options" do
            Puppet.expects(:[]=).with(:name, "puppetmasterd")

            @puppetclean.run_setup
        end

        it "should set log level to debug if --debug was passed" do
            @puppetclean.options.stubs(:[]).with(:debug).returns(true)

            Puppet::Log.expects(:level=).with(:debug)

            @puppetclean.run_setup
        end

        it "should set log level to info if --verbose was passed" do
            @puppetclean.options.stubs(:[]).with(:debug).returns(false)
            @puppetclean.options.stubs(:[]).with(:verbose).returns(true)

            Puppet::Log.expects(:level=).with(:info)

            @puppetclean.run_setup
        end

        it "should set facts terminus to yaml" do
            Puppet::Node::Facts.expects(:terminus_class=).with(:yaml)

            @puppetclean.run_setup
        end

        it "should set node cache as yaml" do
            Puppet::Node.expects(:cache_class=).with(:yaml)

            @puppetclean.run_setup
        end
    end

    describe "when running" do

        before :each do
           # @puppetclean.stubs(:puts)
            @host = 'node'
            ARGV.stubs(:shift).returns(@host)
            ARGV.stubs(:length).returns(1)
            Puppet.stubs(:info)
            [ "cert", "cached_facts", "cached_node", "reports", "storeconfigs" ].each do |m|
                @puppetclean.stubs("clean_#{m}".to_sym).with(@host)
            end
        end

        it "should raise an error if no type is given" do
            ARGV.stubs(:length).returns(0)

            lambda { @puppetclean.main }.should raise_error
        end


        [ "cert", "cached_facts", "cached_node", "reports", "storeconfigs" ].each do |m|
            it "should clean #{m.sub('_',' ')}" do
                @puppetclean.expects("clean_#{m}".to_sym).with(@host)

                @puppetclean.main
            end
        end
    end

    describe "when cleaning certificate" do
        before :each do
            Puppet::SSL::Host.stubs(:destroy)
        end

        it "should send the :destroy order to the SSL host infrastructure" do
            Puppet::SSL::Host.stubs(:destroy).with(@host)

            @puppetclean.clean_cert(@host)
        end
    end

    describe "when cleaning cached facts" do
        it "should destroy facts" do
            Puppet::Node::Facts.expects(:destroy).with(@host)

            @puppetclean.clean_cached_facts(@host)
        end
    end

    describe "when cleaning cached node" do
        it "should destroy the cached node" do
            cache = stub_everything 'cache'
            request = stub_everything 'request'

            Puppet::Node.indirection.stubs(:request).with(:destroy, @host).returns(request)
            Puppet::Node.indirection.stubs(:cache).returns(cache)

            Puppet::Node.indirection.cache.expects(:destroy).with(request)

            @puppetclean.clean_cached_node(@host)
        end
    end

    describe "when cleaning archived reports" do
        it "should tell the reports to remove themselves" do
            Puppet::Transaction::Report.stubs(:destroy).with(@host)

            @puppetclean.clean_reports(@host)
        end
    end

    describe "when cleaning storeconfigs entries for host" do
        before :each do
            @puppetclean.options.stubs(:[]).with(:unexport).returns(false)
            Puppet.features.stubs(:rails?).returns(true)
            Puppet::Rails.stubs(:connect)
            @rails_node = stub_everything 'rails_node'
            Puppet::Rails::Host.stubs(:find_by_name).returns(@rails_node)
            @rail_node.stubs(:destroy)
        end

        it "should connect to the database" do
            Puppet::Rails.expects(:connect)

            @puppetclean.clean_storeconfigs(@host)
        end

        it "should find the right host entry" do
            Puppet::Rails::Host.expects(:find_by_name).with(@host).returns(@rails_node)

            @puppetclean.clean_storeconfigs(@host)
        end

        describe "without unexport" do
            it "should remove the host and it's content" do
                @rails_node.expects(:destroy)

                @puppetclean.clean_storeconfigs(@host)
            end
        end

        describe "with unexport" do
            before :each do
                @puppetclean.options.stubs(:[]).with(:unexport).returns(true)
                @rails_node.stubs(:id).returns(1234)

                @type = stub_everything 'type'
                Puppet::Type.stubs(:type).returns(@type)
                @type.stubs(:validattr?).with(:ensure).returns(true)

                @ensure_name = stub_everything 'ensure_name', :id => 23453
                Puppet::Rails::ParamName.stubs(:find_or_create_by_name).returns(@ensure_name)

                @param_values = stub_everything 'param_values'
                @resource = stub_everything 'resource', :param_values => @param_values, :restype => "File"
                Puppet::Rails::Resource.stubs(:find).returns([@resource])
            end

            it "should find all resources" do
                Puppet::Rails::Resource.expects(:find).with(:all, {:include => {:param_values => :param_name}, :conditions => ["exported=? AND host_id=?", true, 1234]}).returns([])

                @puppetclean.clean_storeconfigs(@host)
            end

            it "should delete the old ensure parameter" do
                ensure_param = stub 'ensure_param', :id => 12345, :line => 12
                @param_values.stubs(:find).returns(ensure_param)

                Puppet::Rails::ParamValue.expects(:delete).with(12345);

                @puppetclean.clean_storeconfigs(@host)
            end

            it "should add an ensure => absent parameter" do
                @param_values.expects(:create).with(:value => "absent",
                                               :line => 0,
                                               :param_name => @ensure_name)


                @puppetclean.clean_storeconfigs(@host)
            end

        end
    end
end
