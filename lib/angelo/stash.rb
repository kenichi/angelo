module Angelo

  # utility class for stashing connected websockets in arbitrary contexts
  #
  class Stash
    include Celluloid::Logger

    # hold the peeraddr info for use after the socket is closed (logging)
    #
    @@peeraddrs = {}

    # the underlying arrays of websockets, by context
    #
    @@stashes = {}

    # create a new instance with a context, creating the array if needed
    #
    def initialize server, context = :default
      raise ArgumentError.new "symbol required" unless Symbol === context
      @context, @server = context, server
      @@stashes[@context] ||= []
    end

    # add a websocket to this context's stash, save peeraddr info, start
    # server handle_websocket task to read from the socket and fire events
    # as needed
    #
    def << ws
      @@peeraddrs[ws] = ws.peeraddr
      @server.async.handle_websocket ws
      @@stashes[@context] << ws
    end

    # access the underlying array of this context
    #
    def stash
      @@stashes[@context]
    end

    # iterate on each connected websocket in this context, handling errors
    # as needed
    #
    def each &block
      stash.each do |ws|
        begin
          yield ws
        rescue Reel::SocketError, IOError, SystemCallError
          remove_socket ws
        end
      end
    end

    # remove a websocket from the stash, warn user, drop peeraddr info
    #
    def remove_socket ws
      if stash.include? ws
        warn "removing socket from context ':#{@context}' (#{@@peeraddrs[ws][2]})"
        stash.delete ws
        @@peeraddrs.delete ws
      end
    end

    # utility method to create a new instance with a different context
    #
    def [] context
      self.class.new @server, context
    end

    # iterate on *every* connected websocket in all contexts, mostly used for
    # ping_websockets task
    #
    def all_each
      @@stashes.values.flatten.each do |ws|
        begin
          yield ws
        rescue Reel::SocketError, IOError, SystemCallError
          remove_socket ws
        end
      end
    end

    # pass the given block to the underlying stashed array's reject! method
    #
    def reject! &block
      stash.reject! &block
    end

    # access the peeraddr info for a given websocket
    #
    def peeraddr ws
      @@peeraddrs[ws]
    end

    # return the number of websockets in this context (some are potentially
    # disconnected)
    #
    def length
      stash.length
    end

  end
end
