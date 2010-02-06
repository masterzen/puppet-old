
require 'net/http'

# This is a wrapper around either a Net::HTTPResponse or a String
# allowing the same interface for the exterior world.
class Puppet::Network::ResponseStream

    attr_accessor :response

    [:code, :body].each do |m|
        define_method(m) do
            response.send(:m)
        end
    end

    def initialize(content)
        @response = content
    end

    def stream?
        response.is_a?(Net::HTTPResponse)
    end

    def content
        response.body
    end

    def length
        if stream?
            response.content_length
        else
            response.length
        end
    end

    def stream
        if stream?
            response.read_body do |r|
                yield r
            end
        else
            yield response.body
        end
    end
end