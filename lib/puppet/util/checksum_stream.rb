
class Puppet::Util::ChecksumStream
    attr_accessor :digest

    def initialize(digest)
        @digest = digest.reset
    end

    def update(chunk)
        digest << chunk
    end

    def checksum
        digest.hexdigest
    end

    def to_s
        "checksum: #{digest}"
    end
end