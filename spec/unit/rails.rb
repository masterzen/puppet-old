#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/storeconfigs/rails'

describe Puppet::Storeconfigs::Rails, "when initializing any connection" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?

    before do
        Puppet.settings.stubs(:use)
        @logger = mock 'logger'
        @logger.stub_everything
        Logger.stubs(:new).returns(@logger)

        ActiveRecord::Base.stubs(:logger).returns(@logger)
        ActiveRecord::Base.stubs(:connected?).returns(false)
    end

    it "should use settings" do
        Puppet.settings.expects(:use).with(:main, :rails, :puppetmasterd)

        Puppet::Storeconfigs::Rails.connect
    end

    it "should set up a logger with the appropriate Rails log file" do
        logger = mock 'logger'
        Logger.expects(:new).with(Puppet[:railslog]).returns(logger)
        ActiveRecord::Base.expects(:logger=).with(logger)

        Puppet::Storeconfigs::Rails.connect
    end

    it "should set the log level to whatever the value is in the settings" do
        Puppet.settings.stubs(:use)
        Puppet.settings.stubs(:value).with(:rails_loglevel).returns("debug")
        Puppet.settings.stubs(:value).with(:railslog).returns("/my/file")
        logger = mock 'logger'
        Logger.stubs(:new).returns(logger)
        ActiveRecord::Base.stubs(:logger).returns(logger)
        logger.expects(:level=).with(Logger::DEBUG)

        ActiveRecord::Base.stubs(:verify_active_connections!)
        ActiveRecord::Base.stubs(:establish_connection)
        Puppet::Storeconfigs::Rails.stubs(:database_arguments)

        Puppet::Storeconfigs::Rails.connect
    end

    it "should call ActiveRecord::Base.verify_active_connections!" do
        ActiveRecord::Base.expects(:verify_active_connections!)

        Puppet::Storeconfigs::Rails.connect
    end

    it "should call ActiveRecord::Base.establish_connection with database_arguments" do
        Puppet::Storeconfigs::Rails.expects(:database_arguments)
        ActiveRecord::Base.expects(:establish_connection)

        Puppet::Storeconfigs::Rails.connect
    end
end

describe Puppet::Storeconfigs::Rails, "when initializing a sqlite3 connection" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?

    it "should provide the adapter, log_level, and dbfile arguments" do
        Puppet.settings.expects(:value).with(:dbadapter).returns("sqlite3")
        Puppet.settings.expects(:value).with(:rails_loglevel).returns("testlevel")
        Puppet.settings.expects(:value).with(:dblocation).returns("testlocation")

        Puppet::Storeconfigs::Rails.database_arguments.should == {
            :adapter => "sqlite3",
            :log_level => "testlevel",
            :dbfile => "testlocation"
        }
    end
end

describe Puppet::Storeconfigs::Rails, "when initializing a mysql or postgresql connection" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?

    it "should provide the adapter, log_level, and host, username, password, and database arguments" do
        Puppet.settings.stubs(:value).with(:dbadapter).returns("mysql")
        Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
        Puppet.settings.stubs(:value).with(:dbserver).returns("testserver")
        Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
        Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
        Puppet.settings.stubs(:value).with(:dbname).returns("testname")
        Puppet.settings.stubs(:value).with(:dbsocket).returns("")

        Puppet::Storeconfigs::Rails.database_arguments.should == {
            :adapter => "mysql",
            :log_level => "testlevel",
            :host => "testserver",
            :username => "testuser",
            :password => "testpassword",
            :database => "testname"
        }
    end

    it "should provide the adapter, log_level, and host, username, password, database, and socket arguments" do
        Puppet.settings.stubs(:value).with(:dbadapter).returns("mysql")
        Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
        Puppet.settings.stubs(:value).with(:dbserver).returns("testserver")
        Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
        Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
        Puppet.settings.stubs(:value).with(:dbname).returns("testname")
        Puppet.settings.stubs(:value).with(:dbsocket).returns("testsocket")

        Puppet::Storeconfigs::Rails.database_arguments.should == {
            :adapter => "mysql",
            :log_level => "testlevel",
            :host => "testserver",
            :username => "testuser",
            :password => "testpassword",
            :database => "testname",
            :socket => "testsocket"
        }
    end
end
