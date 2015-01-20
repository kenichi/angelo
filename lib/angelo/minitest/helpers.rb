require 'websocket/driver'

module Angelo
  module Minitest

    module Helpers

      HTTP_URL = 'http://%s:%d'

      attr_reader :last_response

      def define_app app = nil
        before do
          if app.nil? && block_given?
            app = Class.new Angelo::Base
            app.class_eval { content_type :html }    # reset
            app.class_eval &Proc.new
          end
          Celluloid.logger.level = ::Logger::ERROR # see spec_helper.rb:9

          @server = Angelo::Server.new app
          app.server = @server
          $reactor = Reactor.new if $reactor == nil || !$reactor.alive?
        end

        after do
          sleep 0.1
          @server.terminate if @server and @server.alive?
        end
      end

      def hc
        @hc ||= HTTPClient.new
      end

      def url path = nil
        url = HTTP_URL % [DEFAULT_ADDR, DEFAULT_PORT]
        url += path if path
        url
      end

      def hc_req method, path, params = {}, headers = {}
        @last_response = if block_given?
                           hc.__send__ method, url(path), params, headers, &Proc.new
                         else
                           hc.__send__ method, url(path), params, headers
                         end
      end
      private :hc_req

      def http_req method, path, params = {}, headers = {}
        params = case params
                 when String; {body: params}
                 when Hash
                   case method
                   when :get, :delete, :options
                     {params: params}
                   else
                     {form: params}
                   end
                 end
        @last_response = case
                         when !headers.empty?
                           ::HTTP.with(headers).__send__ method, url(path), params
                         else
                           ::HTTP.__send__ method, url(path), params
                         end
      end
      private :http_req

      [:get, :post, :put, :delete, :options, :head].each do |m|
        define_method m do |path, params = {}, headers = {}|

          # http_req m, path, params, headers

          if block_given?
            hc_req m, path, params, headers, &Proc.new
          else
            hc_req m, path, params, headers
          end
        end
      end

      def get_sse path, params = {}, headers = {}, &block
        @last_response = hc.get url(path), params, headers, &block
      end

      def websocket_helper path, params = {}
        params = params.keys.reduce([]) {|a,k|
          a << CGI.escape(k) + '=' + CGI.escape(params[k])
          a
        }.join('&')

        path += "?#{params}" unless params.empty?
        wsh = WebsocketHelper.new DEFAULT_ADDR, DEFAULT_PORT, path
        if block_given?
          yield wsh
          wsh.close
        else
          return wsh
        end
      end

      def last_response_must_be_html body = ''
        last_response.status.must_equal 200
        last_response.body.to_s.must_equal body
        last_response.headers['Content-Type'].split(';').must_include HTML_TYPE
      end

      def last_response_must_be_json obj = {}
        last_response.status.must_equal 200
        JSON.parse(last_response.body.to_s).must_equal obj
        last_response.headers['Content-Type'].split(';').must_include JSON_TYPE
      end

      module Cellper

        @@stop = false
        @@testers = {}

        def define_action sym, &block
          define_method sym, &block
        end

        def remove_action sym
          remove_method sym
        end

        def unstop!
          @@stop = false
        end

        def stop!
          @@stop = true
        end

        def stop?
          @@stop
        end

        def testers; @@testers; end
      end

      class Reactor
        include Celluloid::IO
        extend Cellper
      end

      class ActorPool
        include Celluloid
        extend Cellper
      end

    end

    class WebsocketHelper
      include Celluloid::Logger

      extend Forwardable
      def_delegator :@socket, :write
      def_delegators :@driver, :binary, :close, :text

      WS_URL = 'ws://%s:%d'

      attr_reader :driver, :socket
      attr_writer :addr, :port, :path, :on_close, :on_message, :on_open

      def initialize addr, port, path
        @addr, @port, @path = addr, port, path
      end

      def init
        init_socket
        init_driver
      end

      def init_socket
        ip = @addr
        ip = Socket.getaddrinfo(@addr, 'http')[0][3] unless @addr =~ /\d+\.\d+\.\d+\.\d+/
        @socket = Celluloid::IO::TCPSocket.new ip, @port
      end

      def init_driver
        @driver = WebSocket::Driver.client self

        @driver.on :open do |e|
          @on_open.call(e) if Proc === @on_open
        end

        @driver.on :message do |e|
          @on_message.call(e) if Proc === @on_message
        end

        @driver.on :close do |e|
          @on_close.call(e) if Proc === @on_close
        end
      end

      def url
        WS_URL % [@addr, @port] + @path
      end

      def go
        @driver.start
        while msg = @socket.readpartial(4096)
          @driver.parse msg
        end
      end

    end

  end

end
