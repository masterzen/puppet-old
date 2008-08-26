# Daemontools service management
#
# author Brice Figureau <brice-puppet@daysofwonder.com>
Puppet::Type.type(:service).provide :runit, :parent => :daemontools do
    desc "Runit service management.
    This provider manages daemons running supervised by Runit.
    It tries to detect the service directory, with by order of preference:
     * /service
     * /var/service
     * /etc/service
    The daemon directory should be placed in a directory that can be 
    by default in:
     * /etc/sv
    or this can be overriden in the service resource parameters:
    service {
     \"myservice\":
       provider => \"runit\", path => \"/path/to/daemons\";
    }

    This provider supports out of the box:
     * start/stop
     * enable/disable
     * restart
     * status"

     commands :sv => "/usr/bin/sv"

    class << self
        # this is necessary to autodetect a valid resource
        # default path, since there is no standard for such directory.
        def defpath
            unless defined?(@defpath) and @defpath
                ["/etc/sv", "/var/lib/service"].each do |path|
                    if FileTest.exist?(path)
                        @defpath = path
                        break
                    end
                end
                raise "Could not find the daemon directory (tested [/var/lib/service,/etc])" unless @defpath
            end
            @defpath
        end
    end

    # find the service dir on this node
    def servicedir
      unless defined?(@servicedir) and @servicedir
        ["/service", "/etc/service","/var/service"].each do |path|
            if FileTest.exist?(path)
                @servicedir = path
                break
            end
        end
        raise "Could not find service directory" unless @servicedir
      end
      @servicedir
    end

    # returns the daemon dir on this node
    def self.daemondir
        self.class.defpath
    end

    def restartcmd
        [ command(:sv), "restart", self.service]
    end

    def status
        begin
            output = sv "status", self.service
            return :running if output =~ /^run /
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error.new( "Could not get status for service %s: %s" % [ resource.ref, detail] )
        end
        return :stopped
    end

    def stopcmd
        [ command(:sv), "stop", self.service]
    end

    # disable by stopping the service
    # and removing the symlink so that svscan
    # doesn't restart our service behind our back
    def disable
        # unlink the daemon symlink to disable it
        File.unlink(self.service) if FileTest.symlink?(self.service)
    end
end

