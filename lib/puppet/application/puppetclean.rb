require 'puppet'
require 'puppet/application'

Puppet::Application.new(:puppetclean) do

    should_not_parse_config

    attr_accessor :host

    option("--debug","-d")
    option("--verbose","-v")
    option("--unexport","-u")

    command(:main) do
        if ARGV.length > 0
            host = ARGV.shift
        else
            raise "You must specify the host to clean"
        end

        [ :clean_cert, :clean_cached_facts, :clean_cached_node, :clean_reports, :clean_storeconfigs ].each do |m|
            begin
                send(m, host)
            rescue => detail
                puts detail.backtrace if Puppet[:trace]
                puts detail.to_s
            end
        end
    end

    # clean signed cert for +host+
    def clean_cert(host)
        Puppet::SSL::Host.destroy(host)
        Puppet.info "%s certificates removed from ca" % host
    end

    # clean facts for +host+
    def clean_cached_facts(host)
        Puppet::Node::Facts.destroy(host)
        Puppet.info "%s's facts removed" % host
    end

    # clean cached node +host+
    def clean_cached_node(host)
        Puppet::Node.indirection.cache.destroy(Puppet::Node.indirection.request(:destroy, host))
        Puppet.info "%s's cached node removed" % host
    end

    # clean node reports for +host+
    def clean_reports(host)
        Puppet::Transaction::Report.destroy(host)
        Puppet.info "%s's reports removed" % host
    end

    # clean store config for +host+
    def clean_storeconfigs(host)
        return unless Puppet.features.rails?

        require 'puppet/rails'
        Puppet::Rails.connect

        return unless rail_host = Puppet::Rails::Host.find_by_name(host)

        if options[:unexport]
            unexport(rail_host)
            Puppet.notice "Force %s's exported resources to absent" % host
            Puppet.warning "Please wait other host have checked-out their configuration before finishing clean-up wih:"
            Puppet.warning "$ puppetclean #{host}"
        else
            rail_host.destroy
            Puppet.notice "%s storeconfigs removed" % host
        end
    end

    def unexport(host)
        # fetch all exported resource
        query = {:include => {:param_values => :param_name}}
        values = [true, host.id]
        query[:conditions] = ["exported=? AND host_id=?", *values]

        Puppet::Rails::Resource.find(:all, query).each do |resource|
            if Puppet::Type.type(resource.restype.downcase.to_sym).validattr?(:ensure)
                line = 0
                param_name = Puppet::Rails::ParamName.find_or_create_by_name("ensure")

                if ensure_param = resource.param_values.find(:first, :conditions => [ 'param_name_id = ?', param_name.id])
                    line = ensure_param.line.to_i
                    Puppet::Rails::ParamValue.delete(ensure_param.id);
                end

                # force ensure parameter to "absent"
                resource.param_values.create(:value => "absent",
                                               :line => line,
                                               :param_name => param_name)
                Puppet.info("%s has been marked as \"absent\"" % resource.name)
            end
        end
    end

    setup do
        Puppet::Util::Log.newdestination(:console)

        Puppet.parse_config

        # let's pretend we are puppetmasterd to access the
        # right configuration settings from puppet.conf
        Puppet[:name] = "puppetmasterd"

        if options[:debug]
            Puppet::Util::Log.level = :debug
        elsif options[:verbose]
            Puppet::Util::Log.level = :info
        end

        Puppet::Node::Facts.terminus_class = :yaml
        Puppet::Node.cache_class = :yaml
    end
end
