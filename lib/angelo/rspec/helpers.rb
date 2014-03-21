require 'websocket/driver'

module Angelo
  module RSpec

    module Helpers

      HTTP_URL = 'http://%s:%d'
      WS_URL = 'ws://%s:%d'

      attr_reader :last_response

      def define_app &block

        before do
          app = Class.new Angelo::Base
          app.class_eval { content_type :html } # reset
          app.class_eval &block
          @server = Angelo::Server.new app
          $reactor = Reactor.new unless $reactor.alive?
        end

        after do
          sleep 0.1
          @server.terminate if @server and @server.alive?
        end

      end

      def hc
        @hc ||= HTTPClient.new
        @hc
      end
      private :hc

      def hc_req method, path, params = {}, headers = {}
        url = HTTP_URL % [DEFAULT_ADDR, DEFAULT_PORT]
        @last_response = hc.__send__ method, url+path, params, headers
      end
      private :hc_req

      [:get, :post, :put, :delete, :options, :head].each do |m|
        define_method m do |path, params = {}, headers = {}|
          hc_req m, path, params, headers
        end
      end

      def socket path, params = {}
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

      def last_response_should_be_html body = ''
        last_response.status.should eq 200
        last_response.body.should eq body
        last_response.headers['Content-Type'].split(';').should include HTML_TYPE
      end

      def last_response_should_be_json obj = {}
        last_response.status.should eq 200
        JSON.parse(last_response.body).should eq obj
        last_response.headers['Content-Type'].split(';').should include JSON_TYPE
      end

    end

    class WebsocketHelper
      include Celluloid::Logger

      extend Forwardable
      def_delegator :@socket, :write
      def_delegators :@driver, :binary, :close, :text

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
