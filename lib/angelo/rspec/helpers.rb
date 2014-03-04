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

      def socket path, params = {}, &block
        begin
          client = TCPSocket.new DEFAULT_ADDR, DEFAULT_PORT

          params = params.keys.reduce([]) {|a,k|
            a << CGI.escape(k) + '=' + CGI.escape(params[k])
            a
          }.join('&')

          url = WS_URL % [DEFAULT_ADDR, DEFAULT_PORT] + path + "?#{params}"

          handshake = WebSocket::ClientHandshake.new :get, url, {
            "Host"                   => "www.example.com",
            "Upgrade"                => "websocket",
            "Connection"             => "Upgrade",
            "Sec-WebSocket-Key"      => "dGhlIHNhbXBsZSBub25jZQ==",
            "Origin"                 => "http://example.com",
            "Sec-WebSocket-Protocol" => "chat, superchat",
            "Sec-WebSocket-Version"  => "13"
          }

          client << handshake.to_data
          yield WebsocketHelper.new client
        ensure
          client.close
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

      def initialize client
        @client = client
        @client.readpartial 4096 # ditch response handshake
      end

      def parser
        @parser ||= WebSocket::Parser.new
      end

      def send msg
        @client << WebSocket::Message.new(msg).to_data
      end

      def recv
        parser.append @client.readpartial(4096) until msg = parser.next_message
        msg
      end

    end

  end
end
