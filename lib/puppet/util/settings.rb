require 'puppet'
require 'sync'
require 'puppet/transportable'
require 'getoptlong'

require 'puppet/external/event-loop'
require 'puppet/util/cacher'
require 'puppet/util/loadedfile'

# The class for handling configuration files.
class Puppet::Util::Settings
    include Enumerable
    include Puppet::Util::Cacher

    attr_accessor :file
    attr_reader :timer

    # Retrieve a config value
    def [](param)
        value(param)
    end

    # Set a config value.  This doesn't set the defaults, it sets the value itself.
    def []=(param, value)
        set_value(param, value, :memory)
    end

    # Generate the list of valid arguments, in a format that GetoptLong can
    # understand, and add them to the passed option list.
    def addargs(options)
        # Add all of the config parameters as valid options.
        self.each { |name, element|
            element.getopt_args.each { |args| options << args }
        }

        return options
    end

    # Generate the list of valid arguments, in a format that OptionParser can
    # understand, and add them to the passed option list.
    def optparse_addargs(options)
        # Add all of the config parameters as valid options.
        self.each { |name, element|
            options << element.optparse_args
        }

        return options
    end

    # Is our parameter a boolean parameter?
    def boolean?(param)
        param = param.to_sym
        if @config.include?(param) and @config[param].kind_of? CBoolean
            return true
        else
            return false
        end
    end

    # Remove all set values, potentially skipping cli values.
    def clear(exceptcli = false)
        @sync.synchronize do
            @values.each do |name, values|
                @values.delete(name) unless exceptcli and name == :cli
            end

            # Don't clear the 'used' in this case, since it's a config file reparse,
            # and we want to retain this info.
            unless exceptcli
                @used = []
            end

            @cache.clear

            @name = nil
        end
    end

    # This is mostly just used for testing.
    def clearused
        @cache.clear
        @used = []
    end

    # Do variable interpolation on the value.
    def convert(value, environment = nil)
        return value unless value
        return value unless value.is_a? String
        newval = value.gsub(/\$(\w+)|\$\{(\w+)\}/) do |value|
            varname = $2 || $1
            if varname == "environment" and environment
                environment
            elsif pval = self.value(varname)
                pval
            else
                raise Puppet::DevError, "Could not find value for %s" % value
            end
        end

        return newval
    end

    # Return a value's description.
    def description(name)
        if obj = @config[name.to_sym]
            obj.desc
        else
            nil
        end
    end

    def each
        @config.each { |name, object|
            yield name, object
        }
    end

    # Iterate over each section name.
    def eachsection
        yielded = []
        @config.each do |name, object|
            section = object.section
            unless yielded.include? section
                yield section
                yielded << section
            end
        end
    end

    # Return an object by name.
    def element(param)
        param = param.to_sym
        @config[param]
    end

    # Handle a command-line argument.
    def handlearg(opt, value = nil)
        @cache.clear
        value = munge_value(value) if value
        str = opt.sub(/^--/,'')
        bool = true
        newstr = str.sub(/^no-/, '')
        if newstr != str
            str = newstr
            bool = false
        end
        str = str.intern

        if value == "" or value.nil?
            value = bool
        end

        set_value(str, value, :cli)
    end

    def include?(name)
        name = name.intern if name.is_a? String
        @config.include?(name)
    end

    # check to see if a short name is already defined
    def shortinclude?(short)
        short = short.intern if name.is_a? String
        @shortnames.include?(short)
    end

    # Create a new collection of config settings.
    def initialize
        @config = {}
        @shortnames = {}

        @created = []
        @searchpath = nil

        # Mutex-like thing to protect @values
        @sync = Sync.new

        # Keep track of set values.
        @values = Hash.new { |hash, key| hash[key] = {} }

        # And keep a per-environment cache
        @cache = Hash.new { |hash, key| hash[key] = {} }

        # A central concept of a name.
        @name = nil

        # The list of sections we've used.
        @used = []
    end

    # NOTE: ACS ahh the util classes. . .sigh
    # as part of a fix for 1183, I pulled the logic for the following 5 methods out of the executables and puppet.rb
    # They probably deserve their own class, but I don't want to do that until I can refactor environments
    # its a little better than where they were

    # Prints the contents of a config file with the available config elements, or it
    # prints a single value of a config element.
    def print_config_options
        env = value(:environment)
        val = value(:configprint)
        if val == "all"
            hash = {}
            each do |name, obj|
                val = value(name,env)
                val = val.inspect if val == ""
                hash[name] = val
            end
            hash.sort { |a,b| a[0].to_s <=> b[0].to_s }.each do |name, val|
                puts "%s = %s" % [name, val]
            end
        else
            val.split(/\s*,\s*/).sort.each do |v|
                if include?(v)
                    #if there is only one value, just print it for back compatibility
                    if v == val
                         puts value(val,env)
                         break
                    end
                    puts "%s = %s" % [v, value(v,env)]
                else
                    puts "invalid parameter: %s" % v
                    return false
                end
            end
        end
        true
    end

    def generate_config
        puts to_config
        true
    end

    def generate_manifest
        puts to_manifest
        true
    end

    def print_configs
        return print_config_options if value(:configprint) != ""
        return generate_config if value(:genconfig)
        return generate_manifest if value(:genmanifest)
    end

    def print_configs?
        return (value(:configprint) != "" || value(:genconfig) || value(:genmanifest)) && true
    end

    # Return a given object's file metadata.
    def metadata(param)
        if obj = @config[param.to_sym] and obj.is_a?(CFile)
            return [:owner, :group, :mode].inject({}) do |meta, p|
                if v = obj.send(p)
                    meta[p] = v
                end
                meta
            end
        else
            nil
        end
    end

    # Make a directory with the appropriate user, group, and mode
    def mkdir(default)
        obj = get_config_file_default(default)

        Puppet::Util::SUIDManager.asuser(obj.owner, obj.group) do
            mode = obj.mode || 0750
            Dir.mkdir(obj.value, mode)
        end
    end

    # Figure out our name.
    def name
        unless @name
            unless @config[:name]
                return nil
            end
            searchpath.each do |source|
                next if source == :name
                @sync.synchronize do
                    @name = @values[source][:name]
                end
                break if @name
            end
            unless @name
                @name = convert(@config[:name].default).intern
            end
        end
        @name
    end

    # Return all of the parameters associated with a given section.
    def params(section = nil)
        if section
            section = section.intern if section.is_a? String
            @config.find_all { |name, obj|
                obj.section == section
            }.collect { |name, obj|
                name
            }
        else
            @config.keys
        end
    end

    # Parse the configuration file.  Just provides
    # thread safety.
    def parse
        raise "No :config setting defined; cannot parse unknown config file" unless self[:config]

        # Create a timer so that this file will get checked automatically
        # and reparsed if necessary.
        set_filetimeout_timer()

        # Retrieve the value now, so that we don't lose it in the 'clear' call.
        file = self[:config]

        return unless FileTest.exist?(file)

        # We have to clear outside of the sync, because it's
        # also using synchronize().
        clear(true)

        @sync.synchronize do
            unsafe_parse(file)
        end
    end

    # Unsafely parse the file -- this isn't thread-safe and causes plenty of problems if used directly.
    def unsafe_parse(file)
        parse_file(file).each do |area, values|
            @values[area] = values
        end

        # Determine our environment, if we have one.
        if @config[:environment]
            env = self.value(:environment).to_sym
        else
            env = "none"
        end

        # Call any hooks we should be calling.
        settings_with_hooks.each do |setting|
            each_source(env) do |source|
                if value = @values[source][setting.name]
                    # We still have to use value() to retrieve the value, since
                    # we want the fully interpolated value, not $vardir/lib or whatever.
                    # This results in extra work, but so few of the settings
                    # will have associated hooks that it ends up being less work this
                    # way overall.
                    setting.handle(self.value(setting.name, env))
                    break
                end
            end
        end

        # We have to do it in the reverse of the search path,
        # because multiple sections could set the same value
        # and I'm too lazy to only set the metadata once.
        searchpath.reverse.each do |source|
            if meta = @values[source][:_meta]
                set_metadata(meta)
            end
        end
    end

    # Create a new element.  The value is passed in because it's used to determine
    # what kind of element we're creating, but the value itself might be either
    # a default or a value, so we can't actually assign it.
    def newelement(hash)
        klass = nil
        if hash[:section]
            hash[:section] = hash[:section].to_sym
        end
        if type = hash[:type]
            unless klass = {:element => CElement, :file => CFile, :boolean => CBoolean}[type]
                raise ArgumentError, "Invalid setting type '%s'" % type
            end
            hash.delete(:type)
        else
            case hash[:default]
            when true, false, "true", "false"
                klass = CBoolean
            when /^\$\w+\//, /^\//
                klass = CFile
            when String, Integer, Float # nothing
                klass = CElement
            else
                raise Puppet::Error, "Invalid value '%s' for %s" % [value.inspect, hash[:name]]
            end
        end
        hash[:settings] = self
        element = klass.new(hash)

        return element
    end

    # This has to be private, because it doesn't add the elements to @config
    private :newelement

    # Iterate across all of the objects in a given section.
    def persection(section)
        section = section.to_sym
        self.each { |name, obj|
            if obj.section == section
                yield obj
            end
        }
    end

    # Cache this in an easily clearable way, since we were
    # having trouble cleaning it up after tests.
    cached_attr(:file) do
        if path = self[:config] and FileTest.exist?(path)
            Puppet::Util::LoadedFile.new(path)
        end
    end

    # Reparse our config file, if necessary.
    def reparse
        if file and file.changed?
            Puppet.notice "Reparsing %s" % file.file
            @sync.synchronize do
                parse
            end
            reuse()
        end
    end

    def reuse
        return unless defined? @used
        @sync.synchronize do # yay, thread-safe
            new = @used
            @used = []
            self.use(*new)
        end
    end

    # The order in which to search for values.
    def searchpath(environment = nil)
        if environment
            [:cli, :memory, environment, :name, :main]
        else
            [:cli, :memory, :name, :main]
        end
    end

    # Get a list of objects per section
    def sectionlist
        sectionlist = []
        self.each { |name, obj|
            section = obj.section || "puppet"
            sections[section] ||= []
            unless sectionlist.include?(section)
                sectionlist << section
            end
            sections[section] << obj
        }

        return sectionlist, sections
    end

    def set_value(param, value, type)
        param = param.to_sym
        unless element = @config[param]
            raise ArgumentError,
                "Attempt to assign a value to unknown configuration parameter %s" % param.inspect
        end
        if element.respond_to?(:munge)
            value = element.munge(value)
        end
        if element.respond_to?(:handle)
            element.handle(value)
        end
        # Reset the name, so it's looked up again.
        if param == :name
            @name = nil
        end
        @sync.synchronize do # yay, thread-safe
            @values[type][param] = value
            @cache.clear
            clearused
        end

        return value
    end

    private :set_value

    # Set a bunch of defaults in a given section.  The sections are actually pretty
    # pointless, but they help break things up a bit, anyway.
    def setdefaults(section, defs)
        section = section.to_sym
        call = []
        defs.each { |name, hash|
            if hash.is_a? Array
                unless hash.length == 2
                    raise ArgumentError, "Defaults specified as an array must contain only the default value and the decription"
                end
                tmp = hash
                hash = {}
                [:default, :desc].zip(tmp).each { |p,v| hash[p] = v }
            end
            name = name.to_sym
            hash[:name] = name
            hash[:section] = section
            if @config.include?(name)
                raise ArgumentError, "Parameter %s is already defined" % name
            end
            tryconfig = newelement(hash)
            if short = tryconfig.short
                if other = @shortnames[short]
                    raise ArgumentError, "Parameter %s is already using short name '%s'" % [other.name, short]
                end
                @shortnames[short] = tryconfig
            end
            @config[name] = tryconfig

            # Collect the settings that need to have their hooks called immediately.
            # We have to collect them so that we can be sure we're fully initialized before
            # the hook is called.
            call << tryconfig if tryconfig.call_on_define
        }

        call.each { |setting| setting.handle(self.value(setting.name)) }
    end

    # Create a timer to check whether the file should be reparsed.
    def set_filetimeout_timer
        return unless timeout = self[:filetimeout] and timeout = Integer(timeout) and timeout > 0
        timer = EventLoop::Timer.new(:interval => timeout, :tolerance => 1, :start? => true) { self.reparse() }
    end

    # Convert the settings we manage into a catalog full of resources that model those settings.
    # We currently have to go through Trans{Object,Bucket} instances,
    # because this hasn't been ported yet.
    def to_catalog(*sections)
        sections = nil if sections.empty?

        catalog = Puppet::Resource::Catalog.new("Settings")

        @config.values.find_all { |value| value.is_a?(CFile) }.each do |file|
            next unless (sections.nil? or sections.include?(file.section))
            next unless resource = file.to_resource
            next if catalog.resource(resource.ref)

            catalog.add_resource(resource)
        end

        add_user_resources(catalog, sections)

        catalog
    end

    # Convert our list of config elements into a configuration file.
    def to_config
        str = %{The configuration file for #{Puppet[:name]}.  Note that this file
is likely to have unused configuration parameters in it; any parameter that's
valid anywhere in Puppet can be in any config file, even if it's not used.

Every section can specify three special parameters: owner, group, and mode.
These parameters affect the required permissions of any files specified after
their specification.  Puppet will sometimes use these parameters to check its
own configured state, so they can be used to make Puppet a bit more self-managing.

Generated on #{Time.now}.

}.gsub(/^/, "# ")

        # Add a section heading that matches our name.
        if @config.include?(:name)
            str += "[%s]\n" % self[:name]
        end
        eachsection do |section|
            persection(section) do |obj|
                str += obj.to_config + "\n"
            end
        end

        return str
    end

    # Convert to a parseable manifest
    def to_manifest
        catalog = to_catalog
        # The resource list is a list of references, not actual instances.
        catalog.resources.collect do |ref|
            catalog.resource(ref).to_manifest
        end.join("\n\n")
    end

    # Create the necessary objects to use a section.  This is idempotent;
    # you can 'use' a section as many times as you want.
    def use(*sections)
        sections = sections.collect { |s| s.to_sym }
        @sync.synchronize do # yay, thread-safe
            sections = sections.reject { |s| @used.include?(s) }

            return if sections.empty?

            begin
                catalog = to_catalog(*sections).to_ral
            rescue => detail
                puts detail.backtrace if Puppet[:trace]
                Puppet.err "Could not create resources for managing Puppet's files and directories in sections %s: %s" % [sections.inspect, detail]

                # We need some way to get rid of any resources created during the catalog creation
                # but not cleaned up.
                return
            end

            begin
                catalog.host_config = false
                catalog.apply do |transaction|
                    if transaction.any_failed?
                        report = transaction.report
                        failures = report.logs.find_all { |log| log.level == :err }
                        raise "Got %s failure(s) while initializing: %s" % [failures.length, failures.collect { |l| l.to_s }.join("; ")]
                    end
                end
            end

            sections.each { |s| @used << s }
            @used.uniq!
        end
    end

    def valid?(param)
        param = param.to_sym
        @config.has_key?(param)
    end

    # Find the correct value using our search path.  Optionally accept an environment
    # in which to search before the other configuration sections.
    def value(param, environment = nil)
        param = param.to_sym
        environment = environment.to_sym if environment

        # Short circuit to nil for undefined parameters.
        return nil unless @config.include?(param)

        # Yay, recursion.
        #self.reparse() unless [:config, :filetimeout].include?(param)

        # Check the cache first.  It needs to be a per-environment
        # cache so that we don't spread values from one env
        # to another.
        if cached = @cache[environment||"none"][param]
            return cached
        end

        # See if we can find it within our searchable list of values
        val = catch :foundval do
            each_source(environment) do |source|
                # Look for the value.  We have to test the hash for whether
                # it exists, because the value might be false.
                @sync.synchronize do
                    if @values[source].include?(param)
                        throw :foundval, @values[source][param]
                    end
                end
            end
            throw :foundval, nil
        end

        # If we didn't get a value, use the default
        val = @config[param].default if val.nil?

        # Convert it if necessary
        val = convert(val, environment)

        # And cache it
        @cache[environment||"none"][param] = val
        return val
    end

    # Open a file with the appropriate user, group, and mode
    def write(default, *args, &bloc)
        obj = get_config_file_default(default)
        writesub(default, value(obj.name), *args, &bloc)
    end

    # Open a non-default file under a default dir with the appropriate user,
    # group, and mode
    def writesub(default, file, *args, &bloc)
        obj = get_config_file_default(default)
        chown = nil
        if Puppet::Util::SUIDManager.uid == 0
            chown = [obj.owner, obj.group]
        else
            chown = [nil, nil]
        end

        Puppet::Util::SUIDManager.asuser(*chown) do
            mode = obj.mode || 0640
            if args.empty?
                args << "w"
            end

            args << mode

            # Update the umask to make non-executable files
            Puppet::Util.withumask(File.umask ^ 0111) do
                File.open(file, *args) do |file|
                    yield file
                end
            end
        end
    end

    def readwritelock(default, *args, &bloc)
        file = value(get_config_file_default(default).name)
        tmpfile = file + ".tmp"
        sync = Sync.new
        unless FileTest.directory?(File.dirname(tmpfile))
            raise Puppet::DevError, "Cannot create %s; directory %s does not exist" %
                [file, File.dirname(file)]
        end

        sync.synchronize(Sync::EX) do
            File.open(file, ::File::CREAT|::File::RDWR, 0600) do |rf|
                rf.lock_exclusive do
                    if File.exist?(tmpfile)
                        raise Puppet::Error, ".tmp file already exists for %s; Aborting locked write. Check the .tmp file and delete if appropriate" %
                            [file]
                    end

                    # If there's a failure, remove our tmpfile
                    begin
                        writesub(default, tmpfile, *args, &bloc)
                    rescue
                        File.unlink(tmpfile) if FileTest.exist?(tmpfile)
                        raise
                    end

                    begin
                        File.rename(tmpfile, file)
                    rescue => detail
                        Puppet.err "Could not rename %s to %s: %s" % [file, tmpfile, detail]
                        File.unlink(tmpfile) if FileTest.exist?(tmpfile)
                    end
                end
            end
        end
    end

    private

    def get_config_file_default(default)
        obj = nil
        unless obj = @config[default]
            raise ArgumentError, "Unknown default %s" % default
        end

        unless obj.is_a? CFile
            raise ArgumentError, "Default %s is not a file" % default
        end

        return obj
    end

    # Create the transportable objects for users and groups.
    def add_user_resources(catalog, sections)
        return unless Puppet.features.root?
        return unless self[:mkusers]

        @config.each do |name, element|
            next unless element.respond_to?(:owner)
            next unless sections.nil? or sections.include?(element.section)

            if user = element.owner and user != "root" and catalog.resource(:user, user).nil?
                resource = Puppet::Resource.new(:user, user, :ensure => :present)
                if self[:group]
                    resource[:gid] = self[:group]
                end
                catalog.add_resource resource
            end
            if group = element.group and ! %w{root wheel}.include?(group) and catalog.resource(:group, group).nil?
                catalog.add_resource Puppet::Resource.new(:group, group, :ensure => :present)
            end
        end
    end

    # Yield each search source in turn.
    def each_source(environment)
        searchpath(environment).each do |source|
            # Modify the source as necessary.
            source = self.name if source == :name
            yield source
        end
    end

    # Return all elements that have associated hooks; this is so
    # we can call them after parsing the configuration file.
    def settings_with_hooks
        @config.values.find_all { |setting| setting.respond_to?(:handle) }
    end

    # Extract extra setting information for files.
    def extract_fileinfo(string)
        result = {}
        value = string.sub(/\{\s*([^}]+)\s*\}/) do
            params = $1
            params.split(/\s*,\s*/).each do |str|
                if str =~ /^\s*(\w+)\s*=\s*([\w\d]+)\s*$/
                    param, value = $1.intern, $2
                    result[param] = value
                    unless [:owner, :mode, :group].include?(param)
                        raise ArgumentError, "Invalid file option '%s'" % param
                    end

                    if param == :mode and value !~ /^\d+$/
                        raise ArgumentError, "File modes must be numbers"
                    end
                else
                    raise ArgumentError, "Could not parse '%s'" % string
                end
            end
            ''
        end
        result[:value] = value.sub(/\s*$/, '')
        return result
    end

    # Convert arguments into booleans, integers, or whatever.
    def munge_value(value)
        # Handle different data types correctly
        return case value
            when /^false$/i; false
            when /^true$/i; true
            when /^\d+$/i; Integer(value)
            when true; true
            when false; false
            else
                value.gsub(/^["']|["']$/,'').sub(/\s+$/, '')
        end
    end

    # This is an abstract method that just turns a file in to a hash of hashes.
    # We mostly need this for backward compatibility -- as of May 2007 we need to
    # support parsing old files with any section, or new files with just two
    # valid sections.
    def parse_file(file)
        text = read_file(file)

        result = Hash.new { |names, name|
            names[name] = {}
        }

        count = 0

        # Default to 'main' for the section.
        section = :main
        result[section][:_meta] = {}
        text.split(/\n/).each { |line|
            count += 1
            case line
            when /^\s*\[(\w+)\]$/
                section = $1.intern # Section names
                # Add a meta section
                result[section][:_meta] ||= {}
            when /^\s*#/; next # Skip comments
            when /^\s*$/; next # Skip blanks
            when /^\s*(\w+)\s*=\s*(.*)$/ # settings
                var = $1.intern

                # We don't want to munge modes, because they're specified in octal, so we'll
                # just leave them as a String, since Puppet handles that case correctly.
                if var == :mode
                    value = $2
                else
                    value = munge_value($2)
                end

                # Check to see if this is a file argument and it has extra options
                begin
                    if value.is_a?(String) and options = extract_fileinfo(value)
                        value = options[:value]
                        options.delete(:value)
                        result[section][:_meta][var] = options
                    end
                    result[section][var] = value
                rescue Puppet::Error => detail
                    detail.file = file
                    detail.line = line
                    raise
                end
            else
                error = Puppet::Error.new("Could not match line %s" % line)
                error.file = file
                error.line = line
                raise error
            end
        }

        return result
    end

    # Read the file in.
    def read_file(file)
        begin
            return File.read(file)
        rescue Errno::ENOENT
            raise ArgumentError, "No such file %s" % file
        rescue Errno::EACCES
            raise ArgumentError, "Permission denied to file %s" % file
        end
    end

    # Set file metadata.
    def set_metadata(meta)
        meta.each do |var, values|
            values.each do |param, value|
                @config[var].send(param.to_s + "=", value)
            end
        end
    end

    # The base element type.
    class CElement
        attr_accessor :name, :section, :default, :setbycli, :call_on_define
        attr_reader :desc, :short

        def desc=(value)
            @desc = value.gsub(/^\s*/, '')
        end

        # get the arguments in getopt format
        def getopt_args
            if short
                [["--#{name}", "-#{short}", GetoptLong::REQUIRED_ARGUMENT]]
            else
                [["--#{name}", GetoptLong::REQUIRED_ARGUMENT]]
            end
        end

        # get the arguments in OptionParser format
        def optparse_args
            if short
                ["--#{name}", "-#{short}", desc, :REQUIRED]
            else
                ["--#{name}", desc, :REQUIRED]
            end
        end

        def hook=(block)
            meta_def :handle, &block
        end

        # Create the new element.  Pretty much just sets the name.
        def initialize(args = {})
            unless @settings = args.delete(:settings)
                raise ArgumentError.new("You must refer to a settings object")
            end

            args.each do |param, value|
                method = param.to_s + "="
                unless self.respond_to? method
                    raise ArgumentError, "%s does not accept %s" % [self.class, param]
                end

                self.send(method, value)
            end

            unless self.desc
                raise ArgumentError, "You must provide a description for the %s config option" % self.name
            end
        end

        def iscreated
            @iscreated = true
        end

        def iscreated?
            if defined? @iscreated
                return @iscreated
            else
                return false
            end
        end

        def set?
            if defined? @value and ! @value.nil?
                return true
            else
                return false
            end
        end

        # short name for the celement
        def short=(value)
            if value.to_s.length != 1
                raise ArgumentError, "Short names can only be one character."
            end
            @short = value.to_s
        end

        # Convert the object to a config statement.
        def to_config
            str = @desc.gsub(/^/, "# ") + "\n"

            # Add in a statement about the default.
            if defined? @default and @default
                str += "# The default value is '%s'.\n" % @default
            end

            # If the value has not been overridden, then print it out commented
            # and unconverted, so it's clear that that's the default and how it
            # works.
            value = @settings.value(self.name)

            if value != @default
                line = "%s = %s" % [@name, value]
            else
                line = "# %s = %s" % [@name, @default]
            end

            str += line + "\n"

            str.gsub(/^/, "    ")
        end

        # Retrieves the value, or if it's not set, retrieves the default.
        def value
            @settings.value(self.name)
        end
    end

    # A file.
    class CFile < CElement
        attr_writer :owner, :group
        attr_accessor :mode, :create

        # Should we create files, rather than just directories?
        def create_files?
            create
        end

        def group
            if defined? @group
                return @settings.convert(@group)
            else
                return nil
            end
        end

        def owner
            if defined? @owner
                return @settings.convert(@owner)
            else
                return nil
            end
        end

        # Set the type appropriately.  Yep, a hack.  This supports either naming
        # the variable 'dir', or adding a slash at the end.
        def munge(value)
            # If it's not a fully qualified path...
            if value.is_a?(String) and value !~ /^\$/ and value !~ /^\// and value != 'false'
                # Make it one
                value = File.join(Dir.getwd, value)
            end
            if value.to_s =~ /\/$/
                @type = :directory
                return value.sub(/\/$/, '')
            end
            return value
        end

        # Return the appropriate type.
        def type
            value = @settings.value(self.name)
            if @name.to_s =~ /dir/
                return :directory
            elsif value.to_s =~ /\/$/
                return :directory
            elsif value.is_a? String
                return :file
            else
                return nil
            end
        end

        # Turn our setting thing into a Puppet::Resource instance.
        def to_resource
            return nil unless type = self.type

            path = self.value

            return nil unless path.is_a?(String)

            # Make sure the paths are fully qualified.
            path = File.join(Dir.getwd, path) unless path =~ /^\//

            return nil unless type == :directory or create_files? or File.exist?(path)
            return nil if path =~ /^\/dev/

            resource = Puppet::Resource.new(:file, path)
            resource[:mode] = self.mode if self.mode

            if Puppet.features.root?
                resource[:owner] = self.owner if self.owner
                resource[:group] = self.group if self.group
            end

            resource[:ensure] = type
            resource[:loglevel] = :debug
            resource[:backup] = false

            resource.tag(self.section, self.name, "settings")

            resource
        end

        # Make sure any provided variables look up to something.
        def validate(value)
            return true unless value.is_a? String
            value.scan(/\$(\w+)/) { |name|
                name = $1
                unless @settings.include?(name)
                    raise ArgumentError,
                        "Settings parameter '%s' is undefined" %
                        name
                end
            }
        end
    end

    # A simple boolean.
    class CBoolean < CElement
        # get the arguments in getopt format
        def getopt_args
            if short
                [["--#{name}", "-#{short}", GetoptLong::NO_ARGUMENT],
                 ["--no-#{name}", GetoptLong::NO_ARGUMENT]]
            else
                [["--#{name}", GetoptLong::NO_ARGUMENT],
                 ["--no-#{name}", GetoptLong::NO_ARGUMENT]]
            end
        end

        def optparse_args
            if short
                ["--[no-]#{name}", "-#{short}", desc, :NONE ]
            else
                ["--[no-]#{name}", desc, :NONE]
            end
        end

        def munge(value)
            case value
            when true, "true"; return true
            when false, "false"; return false
            else
                raise ArgumentError, "Invalid value '%s' for %s" %
                    [value.inspect, @name]
            end
        end
    end
end
