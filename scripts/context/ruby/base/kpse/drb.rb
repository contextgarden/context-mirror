require 'drb'
require 'base/kpse/trees'

class KpseServer

    attr_accessor :port

    def initialize(port=7000)
        @port = port
    end

    def start
        puts "starting drb service at port #{@port}"
        DRb.start_service("druby://localhost:#{@port}", KpseTrees.new)
        trap(:INT) do
            DRb.stop_service
        end
        DRb.thread.join
    end

    def stop
        # todo
    end

end

class KpseClient

    attr_accessor :port

    def initialize(port=7000)
        @port = port
        @kpse = nil
    end

    def start
        # only needed when callbacks are used / slow, due to Socket::getaddrinfo
        # DRb.start_service
    end

    def object
        @kpse = DRbObject.new(nil,"druby://localhost:#{@port}")
    end

end


# SERVER_URI="druby://localhost:8787"
#
#   # Start a local DRbServer to handle callbacks.
#   #
#   # Not necessary for this small example, but will be required
#   # as soon as we pass a non-marshallable object as an argument
#   # to a dRuby call.
#   DRb.start_service
#
#   timeserver = DRbObject.new_with_uri(SERVER_URI)
