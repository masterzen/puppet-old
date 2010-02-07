require 'net/http'
require 'thread'

class Puppet::Network::DeferredResponse

    attr_accessor :request, :uri, :headers, :rest
    attr_accessor :response
    attr_accessor :request_started

    def initialize(request, uri, headers, rest)
        @request = request
        @uri = uri
        @headers = headers
        @rest = rest
        @mutex = Mutex.new
        @chunk_queue = SizedQueue.new(1)
        @got_response = ConditionVariable.new
        @chunk = nil
        @request_started = false
    end

    def stream?
        true
    end

    def length
        start_request
        response.content_length
    end

    def start_request
        # bail out early if we already started the request
        return if request_started?

        # launch the network request
        Thread.new do
            rest.network(request).request_get(uri, headers) do |response|
                # we got a response from server
                @mutex.synchronize do
                    @request_started = true
                    @response = response
                    @got_response.signal
                end

                unless content = rest.deserialize(response)
                    fail "Could not find any content at %s" % request
                end

                stream_response(content.content)
            end
        end

        # wait for the start of the response to be available
        @mutex.synchronize do
            @got_response.wait(@mutex) unless @request_started
        end
    end

    def stream
        start_request
        while true do
            unless chunk = @chunk_queue.pop
                # it's the end
                break
            end

            @checksum.update(chunk) if @checksum

            yield chunk
        end
        return @checksum
    end

    # if we want the stream to be checksummed on the fly
    # either set a Digest or a Puppet::Util::ChecksumStream
    def checksum=(checksum)
        @checksum = checksum
    end

    def request_started?
        @mutex.synchronize do
            return @request_started
        end
    end

    def stream_response(stream)
        stream.response.read_body do |chunk|
            # send chunks to our consumer
            @chunk_queue << chunk
        end
        # it's over guys
        @chunk_queue << nil
    end
end