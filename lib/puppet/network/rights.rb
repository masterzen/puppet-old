require 'ipaddr'
require 'puppet/network/authstore'

# Define a set of rights and who has access to them.
# There are two types of rights:
#  * named rights (ie a common string)
#  * path based rights (which are matched on a longest prefix basis)
class Puppet::Network::Rights

    # We basically just proxy directly to our rights.  Each Right stores
    # its own auth abilities.
    [:allow, :deny].each do |method|
        define_method(method) do |name, *args|
            if obj = right(name)
                obj.send(method, *args)
            else
                raise ArgumentError, "Unknown right '%s'" % name
            end
        end
    end

    # this method is used to add a new allowed +method+ to +name+
    # method applies only to path rights
    def method(name, *args)
        if right = @pathrights.find { |acl| acl.match(name) }
            right.method(*args)
        else
            raise ArgumentError, "'%s' right is not allowing method specification" % name
        end
    end

    def allowed?(name, *args)
        # check first regular entries
        if acl = @namerights[name_to_namespace(name)]
            return acl.allowed?(*args)
        end

        # bail out if there is no pathrights to check
        raise ArgumentError, "Unknown right '%s'" % name if @pathrights.length == 0

        # then check prefix paths
        res = false
        @pathrights.each do |acl|
            if acl.match(name) and (res = acl.allowed?(*args)) != :dunno
                return res
            end
        end
        res
    end

    def initialize()
        @namerights = {}
        @pathrights = []
    end

    def [](name)
        # find first by regular name
        unless right = @namerights[name_to_namespace(name)]
            right = @pathrights.find { |acl| acl.match(name) }
        end
        right
    end

    def include?(name)
        return true if @namerights.include?(name_to_namespace(name))
        return true if @pathrights.find { |acl| acl.name == name }
        return false
    end

    def each
        @namerights.each { |n,v| yield n,v }
        @pathrights.each { |r| yield r.name,r }
    end

    # Define a new right to which access can be provided.
    def newright(name, options = { :type => :name })
        shortname = Right.shortname(name)
        case options[:type]
        when :name
            iname = name_to_namespace(name)
            if @namerights.include? iname
                raise ArgumentError, "Right '%s' is already defined" % name
            else
                @namerights[iname] = Right.new(iname, shortname)
            end
        when :path
            unless name =~ /^\//
                raise ArgumentError, "'%s' is not an absolute uri path" % name
            end

            if @pathrights.find { |acl| acl.name == name }
                raise ArgumentError, "Right '%s' is already defined" % name
            else
                rights = @pathrights << PathRight.new(name, shortname)
                @pathrights = rights.sort { |a,b| b.length <=> a.length }
            end
        else
            raise ArgumentError, "'%s' acl creation should have a type"
        end
    end

    private

    def name_to_namespace(name)
        return name.intern if name.is_a?(String)
        return name
    end

    # Retrieve a right by name.
    def right(name)
        self[name]
    end

    # A right.
    class Right < Puppet::Network::AuthStore
        attr_accessor :name, :shortname, :type

        Puppet::Util.logmethods(self, true)

        def self.shortname(name)
            name.to_s[0..0]
        end

        def initialize(name, shortname = nil)
            @type = :name
            @name = name
            @shortname = shortname
            unless @shortname
                @shortname = Right.shortname(name)
            end
            super()
        end

        def to_s
            "access[%s]" % @name
        end

        # There's no real check to do at this point
        def valid?
            true
        end

        def path?
            false
        end
    end

    # an URI right
    class PathRight < Right
        attr_accessor :methods, :length

        ALL = [:save, :destroy, :find, :search]

        def path?
            true
        end

        def initialize(name, shortname = nil)
            super(name, shortname)

            @length = name.length

            # by default allow this path to respond to all methods
            @methods = ALL
        end

        def allowed?(name, ip, method)
            return :dunno unless @methods.include?(method)
            super(name,ip)
        end

        def method(m)
            m = m.intern if m.is_a?(String)

            unless ALL.include?(m)
                raise ArgumentError, "'%s' is not an allowed value for method directive" % m
            end

            # if we were allowing all methods, then starts from scratch
            if @methods === ALL
                @methods = []
            end

            if @methods.include?(m)
                raise ArgumentError, "'%s' is already in the '%s' ACL" % [m, name]
            end

            @methods << m
        end

        def match(path)
            return false if path.length < @length
            return path[0..(@length-1)] == name
        end

    end

end

