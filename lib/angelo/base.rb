module Angelo

  class Base
    include ParamsParser
    include Celluloid::Logger

    extend Forwardable
    def_delegators :@responder, :content_type, :headers, :redirect, :request

    @@addr = DEFAULT_ADDR
    @@port = DEFAULT_PORT

    @@ping_time = DEFAULT_PING_TIME
    @@log_level = DEFAULT_LOG_LEVEL

    @@report_errors = false

    if ARGV.any? and not Kernel.const_defined?('Minitest')
      require 'optparse'
      OptionParser.new { |op|
        op.on('-p port',   'set the port (default is 4567)')      { |val| @@port = Integer(val) }
        op.on('-o addr',   "set the host (default is #{@@addr})") { |val| @@addr = val }
      }.parse!(ARGV.dup)
    end

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

      def before opts = {}, &block
        define_method :before, &block
      end

      def after opts = {}, &block
        define_method :after, &block
      end

      HTTPABLE.each do |m|
        define_method m do |path, &block|
          routes[m][path] = Responder.new &block
        end
      end

      def websocket path, &block
        routes[:websocket][path] = WebsocketResponder.new &block
      end

      def on_pong &block
        WebsocketResponder.on_pong = block
      end

      def task name, &block
        Angelo::Server.define_task name, &block
      end

      def websockets
        @websockets ||= Stash::Websocket.new server
        @websockets.reject! &:closed?
        @websockets
      end

      def sses
        @sses ||= Stash::SSE.new server
        @sses.reject! &:closed?
        @sses
      end

      def content_type type
        Responder.content_type type
      end

      def run addr = @@addr, port = @@port
        Celluloid.logger.level = @@log_level
        @server = Angelo::Server.new self, addr, port
        @server.async.ping_websockets
        trap "INT" do
          @server.terminate if @server and @server.alive?
          exit
        end
        sleep
      end

      def local_path path
        if public_dir
          lp = File.join(public_dir, path)
          File.file?(lp) ? lp : nil
        end
      end

      def sse_event event_name, data
        SSE_EVENT_TEMPLATE % [event_name.to_s, data]
      end

      def sse_message data
        SSE_DATA_TEMPLATE % data
      end

    end

    def async meth, *args
      self.class.server.async.__send__ meth, *args
    end

    def future meth, *args
      self.class.server.future.__send__ meth, *args
    end

    def params
      @params ||= case request.method
                  when GET;  parse_query_string
                  when POST; parse_post_body
                  when PUT;  parse_post_body
                  end
    end

    def websockets; self.class.websockets; end
    def sses; self.class.sses; end

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
      rescue IOError
        websockets.remove_socket ws
      end
    end

    task :ping_websockets do
      every(@@ping_time) do
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
        warn e.message if @@report_errors
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

    def eventsource &block
      headers SSE_HEADER
      async :handle_event_source, responder.connection.detach.socket, block
      halt 200, :sse
    end

    def report_errors?
      @@report_errors
    end

    def sleep time
      Celluloid.sleep time
    end

    def sse_event event_name, data; self.class.sse_event event_name, data; end
    def sse_message data; self.class.sse_message data; end

  end

end
