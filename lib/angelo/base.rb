module Angelo

  class Base
    extend Forwardable
    include ParamsParser
    include Celluloid::Logger
    include Templates
    include Tilt::ERB
    include Mustermann

    def_delegators :@responder, :content_type, :headers, :mustermann, :redirect, :request, :transfer_encoding
    def_delegators :@klass, :public_dir, :report_errors?, :sse_event, :sse_message, :sses, :websockets

    attr_accessor :responder

    class << self

      attr_accessor :app_file, :server

      def root
        @root ||= File.expand_path '..', app_file
      end

      def inherited subclass

        # Set app_file by groveling up the caller stack until we find
        # the first caller from a directory different from __FILE__.
        # This allows base.rb to be required from an arbitrarily deep
        # nesting of require "angelo/<whatever>" and still set
        # app_file correctly.
        #
        subclass.app_file = caller_locations.map(&:absolute_path).find do |f|
          !f.start_with?(File.dirname(__FILE__) + File::SEPARATOR)
        end

        # bring RequestError into this namespace
        #
        subclass.class_eval 'class RequestError < Angelo::RequestError; end'

        subclass.addr DEFAULT_ADDR
        subclass.port DEFAULT_PORT

        subclass.ping_time DEFAULT_PING_TIME
        subclass.log_level DEFAULT_LOG_LEVEL

        # Parse command line options if angelo/main has been required.
        # They could also be parsed in run, but this makes them
        # available to and overridable by the DSL.
        #
        subclass.parse_options(ARGV.dup) if @angelo_main

      end
    end

    # Methods defined in module DSL will be available in the DSL both
    # in Angelo::Base subclasses and in the top level DSL.

    module DSL
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

      def task name, &block
        Angelo::Server.define_task name, &block
      end

      def before opts = {}, &block
        filter :before, opts, &block
      end

      def after opts = {}, &block
        filter :after, opts, &block
      end

      def on_pong &block
        Responder::Websocket.on_pong = block
      end

      def content_type type
        Responder.content_type type
      end

    end

    # Make the DSL methods available to subclass-level code.
    # main.rb makes them available to the top level.

    extend DSL

    class << self
      def report_errors?
        !!@report_errors
      end

      def routes
        @routes ||= Hash.new{|h,k| h[k] = RouteMap.new}
      end

      def filters
        @filters ||= {
          before: Hash.new{|h,k| h[k] = []},
          after: Hash.new{|h,k| h[k] = []},
        }
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
        filters[which][pattern] << block
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
          _, value = request.headers.find {|header_key,v| header_key.upcase == k}
          hash[key] = value
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
          if mustermann_params = pattern.params(request.path)
            pre_filter_params = params
            @params = pre_filter_params.merge mustermann_params
            filters.each {|filter| instance_eval &filter}
            @params = pre_filter_params
          end
        end
      end
    end

    # It seems more sensible to put this in main.rb since it's used
    # only if angelo/main is required, but it's here so it can be
    # tested, since requiring angelo/main doesn't play well with the
    # test code.

    def self.parse_options(argv)
      require "optparse"

      optparse = OptionParser.new do |op|
        op.banner = "Usage: #{$0} [options]"

        op.on('-p port', OptionParser::DecimalInteger, "set the port (default is #{port})") {|val| port val}
        op.on('-o addr', "set the host (default is #{addr})") {|val| addr val}
        op.on('-h', '--help', "Show this help") do
          puts op
          exit
        end
      end

      begin
        optparse.parse(argv)
      rescue OptionParser::ParseError => ex
        $stderr.puts ex
        $stderr.puts optparse
        exit 1
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
        mustermann, responder = @hash.find {|k,v| k.match(route)}
        responder.mustermann = mustermann if mustermann
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
