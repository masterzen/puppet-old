#
#  Created by Luke Kanies on 2007-9-22.
#  Copyright (c) 2007. All rights reserved.

require 'puppet'
require 'puppet/util/checksums'
require 'puppet/indirector'

# A checksum class to model translating checksums to file paths.  This
# is the new filebucket.
class Puppet::Checksum
    class << self
        include Puppet::Util::Checksums
    end

    extend Puppet::Indirector

    indirects :checksum, :terminus_class => :file

    attr_reader :algorithm, :content, :path

    def algorithm=(value)
        unless self.class.respond_to?(value)
            raise ArgumentError, "Checksum algorithm %s is not supported" % value
        end
        value = value.intern if value.is_a?(String)
        @algorithm = value
        # Reset the checksum so it's forced to be recalculated.
        @checksum = nil
    end

    # Calculate (if necessary) and return the checksum
    def checksum
        unless @checksum
            @checksum = self.class.send(algorithm, content)
        end
        @checksum
    end

    def initialize(content, options = {})
        raise ArgumentError.new("You must specify the content") unless content

        @path = options[:path] if options.include? :path
        @content = content

        # Init to avoid warnings.
        @checksum = nil

        self.algorithm = options[:algorithm] || :md5
    end

    # This is here so the Indirector::File terminus works correctly.
    def name
        checksum
    end

    def to_s
        "Checksum<{%s}%s>" % [algorithm, checksum]
    end

    def self.restore(file, sum, algorithm="md5")
        restore = true
        if FileTest.exists?(file)
            cursum = send(algorithm, ::File.read(file))

            # if the checksum has changed...
            # this might be extra effort
            if cursum == sum
                restore = false
            end
        end

        if restore
            if newcontents = find(sum).content
                tmp = ""
                newsum = send(algorithm, newcontents)
                changed = nil
                if FileTest.exists?(file) and ! FileTest.writable?(file)
                    changed = ::File.stat(file).mode
                    ::File.chmod(changed | 0200, file)
                end
                ::File.open(file, ::File::WRONLY|::File::TRUNC|::File::CREAT) { |of|
                    of.print(newcontents)
                }
                if changed
                    ::File.chmod(changed, file)
                end
            else
                Puppet.err "Could not find file with checksum %s" % sum
                return nil
            end
            return newsum
        else
            return nil
        end
    end
end
