module Angelo

  class Base
    extend Forwardable
    include ParamsParser
    include Celluloid::Logger
    include Tilt::ERB
    include Mustermann

    def_delegators :@responder, :content_type, :headers, :mustermann, :redirect, :request, :transfer_encoding
    def_delegators :@klass, :public_dir, :report_errors?, :sse_event, :sse_message, :sses, :websockets

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

      def views_dir d = nil
        @views_dir = d if d
        @views_dir ||= DEFAULT_VIEWS_DIR
        File.join root, @views_dir
      end

      def public_dir d = nil
        @public_dir = d if d
        @public_dir ||= DEFAULT_PUBLIC_DIR
        File.join root, @public_dir
      end

      def report_errors!
        @report_errors = true
      end

      def report_errors?
        !!@report_errors
      end

      def routes
        @routes ||= Hash.new{|h,k| h[k] = RouteMap.new}
      end

      def filters
        @filters ||= {before: {default: []}, after: {default: []}}
      end

      def filter which, opts = {}, &block
        case opts
        when String
          filter_by which, opts, block
        when Hash
          if opts[:path]
            filter_by which, opts[:path], block
          else
            filters[which][:default] << block
          end
        end
      end

      def filter_by which, path, block
        pattern = ::Mustermann.new path
        filters[which][pattern] ||= []
        filters[which][pattern] << block
      end

      def before opts = {}, &block
        filter :before, opts, &block
      end

      def after opts = {}, &block
        filter :after, opts, &block
      end

      HTTPABLE.each do |m|
        define_method m do |path, opts = {}, &block|
          path = ::Mustermann.new path, opts
          routes[m][path] = Responder.new &block
        end
      end

      def websocket path, &block
        path = ::Mustermann.new path
        routes[:websocket][path] = Responder::Websocket.new &block
      end

      def eventsource path, headers = nil, &block
        path = ::Mustermann.new path
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

      def run! _addr = addr, _port = port, options = {}
        run _addr, _port, options, true
      end

      def run _addr = addr, _port = port, options = {}, blocking = false
        Celluloid.logger.level = log_level
        @server = Angelo::Server.new self, _addr, _port, options
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
                    parse_query_string_and_post_body
                  end.merge mustermann.params(request.path)
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
        warn e.message if report_errors?
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
      lp = local_file[0] == File::SEPARATOR ? local_file : File.expand_path(File.join(self.class.root, local_file))
      halt 404 unless File.exist? lp

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

    def chunked_response &block
      transfer_encoding :chunked
      ChunkedResponse.new &block
    end

    def filter which
      self.class.filters[which].each do |pattern, filters|
        case pattern
        when :default
          filters.each {|filter| instance_eval &filter}
        when ::Mustermann
          if pattern.match request.path
            @pre_filter_params = params
            @params = @pre_filter_params.merge pattern.params(request.path)
            filters.each {|filter| instance_eval &filter}
            @params = @pre_filter_params
          end
        end
      end
    end

    class RouteMap

      def initialize
        @hash = Hash.new
      end

      def []= route, responder
        @hash[route] = responder
      end

      def [] route
        responder = nil
        if mustermann = @hash.keys.select {|k| k.match(route)}.first
          responder = @hash.fetch mustermann
          responder.mustermann = mustermann
        end
        responder
      end

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
