require 'puppet/network/authconfig'

module Puppet
    class Network::RestAuthConfig < Network::AuthConfig

        attr_accessor :rights

        def self.main
            add_acl = @main.nil?
            super
            @main.mk_default_acls if add_acl and !@main.exists?
            @main
        end

        # check wether this request is allowed in our ACL
        def allowed?(request)
            read()
            return @rights.allowed?(build_uri(request), request.node, request.ip, request.method)
        end

        def initialize(file = nil, parsenow = true)
            super(file || Puppet[:rest_authconfig], parsenow)

            # if we didn't read a file (ie it doesn't exist)
            # make sure we can create some default rights
            @rights ||= Puppet::Network::Rights.new
        end

        def parse()
            super()
            insert_missing_acl
        end

        # force regular ACLs to be present
        def insert_missing_acl
            {
                :facts =>   { :acl => "/facts", :method => :save },
                :catalog => { :acl => "/catalog", :method => :find },
                :file =>    { :acl => "/file" },
                :cert =>    { :acl => "/certificate", :method => :find },
                :reports => { :acl => "/report", :method => :save }
            }.each do |name, acl|
                unless rights[acl[:acl]]
                    Puppet.warning "Inserting default '#{acl[:acl]}' acl because none were found in '%s'" % @file
                    mk_acl(acl[:acl], acl[:method])
                end
            end
        end

        def mk_default_acls
            Puppet.notice "Adding default ACLs"
            mk_acl("/facts", [:save, :find])
            mk_acl("/catalog", :find)
            mk_acl("/report", :save)
            mk_acl("/certificate", :find)

            # this one will allow all file access, and thus delegate
            # to fileserver.conf
            mk_acl("/file")

            # queue an empty (ie deny all) right for every other path
            # actually this is not strictly necessary as the rights system
            # denies not explicitely allowed paths
            rights.newright("/", :type => :path)
        end

        def mk_acl(path, method = nil)
            @rights.newright(path, :type => :path)
            @rights.allow(path, "*")

            if method
                method = [method] unless method.is_a?(Array)
                method.each { |m| @rights.method(path, m) }
            end
        end

        def build_uri(request)
            "/#{request.indirection_name}/#{request.key}"
        end
    end
end
