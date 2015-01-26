module Angelo
  class Responder
    class Websocket < Responder

      class << self

        attr_writer :on_pong

        def on_pong
          @on_pong ||= ->(e){}
        end

      end

      def request= request
        @params = nil
        @request = request
        @websocket = @request.websocket
      end

      def handle_request
        begin
          if @response_handler
            Angelo.log @connection, @request, @websocket, :switching_protocols
            @websocket.on_pong &Responder::Websocket.on_pong
            @base.filter :before
            @base.instance_exec(@websocket, &@response_handler)
            @base.filter :after
          else
            raise NotImplementedError
          end
        rescue IOError => ioe
          warn "#{ioe.class} - #{ioe.message}"
          close_websocket
        rescue => e
          error e.message
          ::STDERR.puts e.backtrace
          begin
            @connection.close
          rescue Reel::StateError => rcse
            close_websocket
          end
        end
      end

      def close_websocket
        @websocket.close
        @base.websockets.remove_socket @websocket
      end

    end
  end
end
