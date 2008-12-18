#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/checksum'
require 'puppet/network/server'
require 'puppet/network/http/webrick/rest'

describe "Filebucket REST Terminus" do
    before do
        Puppet[:masterport] = 34343
        Puppet[:server] = "localhost"

        # Get a safe temporary file
        @tmpfile = Tempfile.new("webrick_integration_testing")
        @dir = @tmpfile.path + "_dir"

        Puppet.settings[:confdir] = @dir
        Puppet.settings[:vardir] = @dir
        Puppet.settings[:server] = "127.0.0.1"
        Puppet.settings[:masterport] = "34343"
        Puppet.settings[:http_enable_post_connection_check] = false

        Puppet::Util::Cacher.expire

        Puppet[:servertype] = 'webrick'
        Puppet[:server] = '127.0.0.1'
        Puppet[:certname] = '127.0.0.1'

        # Generate the certificate with a local CA
        Puppet::SSL::Host.ca_location = :local
        ca = Puppet::SSL::CertificateAuthority.new
        ca.generate(Puppet[:certname]) unless Puppet::SSL::Certificate.find(Puppet[:certname])
        ca.generate("foo.madstop.com") unless Puppet::SSL::Certificate.find(Puppet[:certname])

        @host = Puppet::SSL::Host.new(Puppet[:certname])

        @params = { :address => "127.0.0.1", :port => 34343, :handlers => [ :checksum ] }
        @server = Puppet::Network::Server.new(@params)
        @server.listen

        @old_terminus = Puppet::Checksum.indirection.terminus_class
        Puppet::Checksum.terminus_class = :rest

        # LAK:NOTE We need to have a fake model here so that our indirected methods get
        # passed through REST; otherwise we'd be stubbing 'find', which would cause an immediate
        # return.
        @checksum = stub_everything 'checksum'
        @mock_model = stub('faked model', :name => "checksum", :convert_from => @checksum)
        Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:model).returns(@mock_model)
    end

    after do
        Puppet::Network::HttpPool.expire
        Puppet::SSL::Host.ca_location = :none
        Puppet.settings.clear
        @server.unlisten
        Puppet::Checksum.terminus_class = @old_terminus
    end

    it "should be able save a file to the remote filebucket" do
        @checksum.expects(:save)

        checksum = Puppet::Checksum.new("pouet")
        checksum.save()
    end
end
