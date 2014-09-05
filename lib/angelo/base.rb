module Angelo

  class Base
    include ParamsParser
    include Celluloid::Logger

    extend Forwardable
    def_delegators :@responder, :content_type, :headers, :redirect, :request
    def_delegators :@klass, :websockets, :sses, :sse_event, :sse_message

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
        run! :new, addr, port
      end

      def supervise addr = @@addr, port = @@port
        run! :supervise, addr, port
      end

      def run! meth, addr, port
        Celluloid.logger.level = @@log_level
        @server = Angelo::Server.__send__ meth, self, addr, port
        trap "INT" do
          @server.terminate if @server and @server.alive?
          exit
        end
        sleep
      end
      private :run!

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
      async :handle_event_source, responder.connection.detach.socket, block
      halt 200, :sse
    end

    def report_errors?
      @@report_errors
    end

    def sleep time
      Celluloid.sleep time
    end

    def filter which
      fs = self.class.filters[which][:default]
      fs += self.class.filters[which][request.path] if self.class.filters[which][request.path]
      fs.each {|f| f.bind(self).call}
    end

  end

end
