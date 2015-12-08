module Angelo

  # utility class for stashing connected websockets in arbitrary contexts
  #
  module Stash
    include Celluloid::Internals::Logger

    module ClassMethods

      # the underlying arrays of websockets, by context
      #
      def stashes
        @stashes ||= {}
      end

      # hold the peeraddr info for use after the socket is closed (logging)
      #
      def peeraddrs
        @peeraddrs ||= {}
      end

    end

    def stashes; self.class.stashes; end
    def peeraddrs; self.class.peeraddrs; end

    # create a new instance with a context, creating the array if needed
    #
    def initialize server, context = :default
      raise ArgumentError.new "symbol required" unless Symbol === context
      @context, @server = context, server
      @mutex = Mutex.new
      stashes[@context] ||= []
    end

    # add a websocket to this context's stash, save peeraddr info, start
    # server handle_websocket task to read from the socket and fire events
    # as needed
    #
    def << s
      peeraddrs[s] = s.peeraddr
      stashes[@context] << s
    end

    # access the underlying array of this context
    #
    def stash
      stashes[@context]
    end

    # iterate on each connected websocket in this context, handling errors
    # as needed
    #
    def each &block
      stash_dup = @mutex.synchronize { stash.dup }
      stash_dup.each do |s|
        begin
          yield s
        rescue Reel::SocketError, IOError, SystemCallError => e
          debug "context: #{@context} - #{e.message}"
          remove_socket s
        end
      end
      nil
    end

    # remove a socket from the stash, warn user, drop peeraddr info
    #
    def remove_socket s
      s.close unless s.closed?
      if stash.include? s
        warn "removing socket from context ':#{@context}' (#{peeraddrs[s][2]})"
        stash.delete s

        peeraddrs.delete s
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
      all_stashed = @mutex.synchronize { stashes.values.flatten }
      all_stashed.each do |s|
        begin
          yield s
        rescue Reel::SocketError, IOError, SystemCallError => e
          debug "all - #{e.message}"
          remove_socket s
          stashes.values.each {|_s| _s.delete s}
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
    def peeraddr s
      peeraddrs[s]
    end

    # return the number of websockets in this context (some are potentially
    # disconnected)
    #
    def length
      stash.length
    end

    class Websocket
      extend Stash::ClassMethods
      include Stash

      def << ws
        super
        @server.async.handle_websocket ws
      end

    end

    class SSE
      extend Stash::ClassMethods
      include Stash

      def event *args
        name, data = args
        raise ArgumentError if @context == :default and data.nil?
        data, name = name, @context if data.nil?
        each {|s| s.write Angelo::Base.sse_event(name, data)}
        nil
      end

      def message data
        each {|s| s.write Angelo::Base.sse_message(data)}
        nil
      end

    end

  end

end
