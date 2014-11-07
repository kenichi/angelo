module Angelo

  class Base
    include ParamsParser
    include Celluloid::Logger

    extend Forwardable
    def_delegators :@responder, :content_type, :headers, :redirect, :request, :transfer_encoding
    def_delegators :@klass, :report_errors?, :sse_event, :sse_message, :sses, :websockets

    attr_accessor :responder

    class << self

      attr_accessor :app_file, :server

      def inherited subclass

        # set app_file from caller stack
        #
        subclass.app_file = caller(1).map {|l| l.split(/:(?=|in )/, 3)[0,1]}.flatten[0]

        # bring RequestError into this namespace
        #
        subclass.class_eval 'class RequestError < Angelo::RequestError; end'

        subclass.addr DEFAULT_ADDR
        subclass.port DEFAULT_PORT

        subclass.ping_time DEFAULT_PING_TIME
        subclass.log_level DEFAULT_LOG_LEVEL

        class << subclass

          def root
            @root ||= File.expand_path '..', app_file
          end

          def view_dir
            v = self.class_variable_get(:@@views) rescue DEFAULT_VIEW_DIR
            File.join root, v
          end

          def public_dir
            p = self.class_variable_get(:@@public_dir) rescue DEFAULT_PUBLIC_DIR
            File.join root, p
          end

        end

      end

      def addr a = nil
        @addr = a if a
        @addr
      end

      def log_level ll = nil
        @log_level = ll if ll
        @log_level
      end

      def ping_time pt = nil
        @ping_time = pt if pt
        @ping_time
      end

      def port p = nil
        @port = p if p
        @port
      end

      def report_errors!
        @report_errors = true
      end

      def report_errors?
        !!@report_errors
      end

      def compile! name, &block
        define_method name, &block
        method = instance_method name
        remove_method name
        method
      end

      def routes
        @routes ||= {}
        ROUTABLE.each do |m|
          @routes[m] ||= {}
        end
        @routes
      end

      def filters
        @filters ||= {before: {default: []}, after: {default: []}}
      end

      def filter which, opts = {}, &block
        f = compile! :filter, &block
        case opts
        when String
          filter_by which, opts, f
        when Hash
          if opts[:path]
            filter_by which, opts[:path], f
          else
            filters[which][:default] << f
          end
        end
      end

      def filter_by which, path, meth
        filters[which][path] ||= []
        filters[which][path] << meth
      end

      def before opts = {}, &block
        filter :before, opts, &block
      end

      def after opts = {}, &block
        filter :after, opts, &block
      end

      HTTPABLE.each do |m|
        define_method m do |path, &block|
          routes[m][path] = Responder.new &block
        end
      end

      def websocket path, &block
        routes[:websocket][path] = Responder::Websocket.new &block
      end

      def eventsource path, headers = nil, &block
        routes[:get][path] = Responder::Eventsource.new headers, &block
      end

      def on_pong &block
        Responder::Websocket.on_pong = block
      end

      def task name, &block
        Angelo::Server.define_task name, &block
      end

      def websockets reject = true
        @websockets ||= Stash::Websocket.new server
        @websockets.reject! &:closed? if reject
        @websockets
      end

      def sses reject = true
        @sses ||= Stash::SSE.new server
        @sses.reject! &:closed? if reject
        @sses
      end

      def content_type type
        Responder.content_type type
      end

      def run! _addr = addr, _port = port
        run _addr, _port, true
      end

      def run _addr = addr, _port = port, blocking = false
        Celluloid.logger.level = log_level
        @server = Angelo::Server.new self, _addr, _port
        @server.async.ping_websockets
        if blocking
          trap "INT" do
            @server.terminate if @server and @server.alive?
            exit
          end
          sleep
        end
        @server
      end

      def local_path path
        if public_dir
          lp = File.join(public_dir, path)
          File.file?(lp) ? lp : nil
        end
      end

      def sse_event event_name, data
        data = data.to_json if Hash === data
        SSE_EVENT_TEMPLATE % [event_name.to_s, data]
      end

      def sse_message data
        data = data.to_json if Hash === data
        SSE_DATA_TEMPLATE % data
      end

    end

    def initialize responder
      @responder = responder
      @klass = self.class
    end

    def async meth, *args
      self.class.server.async.__send__ meth, *args
    end

    def future meth, *args
      self.class.server.future.__send__ meth, *args
    end

    def params
      @params ||= case request.method
                  when GET, DELETE, OPTIONS
                    parse_query_string
                  when POST, PUT
                    parse_post_body
                  end
    end

    def request_headers
      @request_headers ||= Hash.new do |hash, key|
        if Symbol === key
          k = key.to_s.upcase
          k.gsub! UNDERSCORE, DASH
          rhv = request.headers.select {|header_key,v| header_key.upcase == k}
          hash[key] = rhv.values.first
        end
      end
    end

    task :handle_websocket do |ws|
      begin
        while !ws.closed? do
          ws.read
        end
      rescue Reel::SocketError, IOError, SystemCallError => e
        debug "ws: #{ws} - #{e.message}"
        websockets.remove_socket ws
      end
    end

    task :ping_websockets do
      every(@base.ping_time) do
        websockets.all_each do |ws|
          ws.socket << ::WebSocket::Message.ping.to_data
        end
      end
    end

    task :handle_event_source do |socket, block|
      begin
        block[socket]
      rescue Reel::SocketError, IOError, SystemCallError => e
        # probably closed on client
        warn e.message if report_errors
        socket.close unless socket.closed?
      rescue => e
        error e.inspect
        socket.close unless socket.closed?
      end
    end

    def halt status = 400, body = ''
      throw :halt, HALT_STRUCT.new(status, body)
    end

    def send_file local_file, opts = {}
      lp = self.class.local_path local_file

      # Content-Type
      #
      headers CONTENT_TYPE_HEADER_KEY =>
        (MIME::Types.type_for(File.extname(lp))[0].content_type rescue HTML_TYPE)

      # Content-Disposition
      #
      if opts[:disposition] == :attachment or opts[:filename]
        headers CONTENT_DISPOSITION_HEADER_KEY =>
          ATTACHMENT_CONTENT_DISPOSITION % (opts[:filename] or File.basename(lp))
      end

      # Content-Length
      #
      headers CONTENT_LENGTH_HEADER_KEY => File.size(lp)

      halt 200, File.read(lp)
    end

    def send_data data, opts = {}
      # Content-Type
      #
      headers CONTENT_TYPE_HEADER_KEY =>
        (MIME::Types.type_for(File.extname(opts[:filename]))[0].content_type rescue HTML_TYPE)

      # Content-Disposition
      #
      if opts[:disposition] == :attachment
        headers CONTENT_DISPOSITION_HEADER_KEY =>
          ATTACHMENT_CONTENT_DISPOSITION % opts[:filename]
      end

      # Content-Length
      #
      headers CONTENT_LENGTH_HEADER_KEY => data.length

      halt 200, data
    end

    def eventsource &block
      headers SSE_HEADER
      async :handle_event_source, EventSource.new(responder), block
      halt 200, :sse
    end

    def sleep time
      Celluloid.sleep time
    end

    def filter which
      fs = self.class.filters[which][:default]
      fs += self.class.filters[which][request.path] if self.class.filters[which][request.path]
      fs.each {|f| f.bind(self).call}
    end

    def chunked_response &block
      transfer_encoding :chunked
      ChunkedResponse.new &block
    end

    class EventSource
      extend Forwardable

      def_delegators :@socket, :close, :closed?, :<<, :write, :peeraddr
      attr_reader :responder, :socket

      def initialize responder
        @responder = responder
        @socket = @responder.connection.detach.socket
      end

      def event name, data = nil
        @socket.write Base.sse_event(name, data)
      end

      def message data
        @socket.write Base.sse_message(data)
      end

      def on_close &block
        @responder.on_close = block
      end

      def on_close= block
        raise ArgumentError.new unless Proc === block
        @responder.on_close = block
      end

    end

    class ChunkedResponse

      def initialize &block
        @chunker = block
      end

      def each &block
        @chunker[block]
      end

    end

  end

end
