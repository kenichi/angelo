module Angelo

  class WebsocketResponder < Responder

    def params
      @params ||= parse_query_string
      @params
    end

    def request= request
      @params = nil
      @request = request
      @websocket = @request.websocket
      handle_request
    end

    def handle_request
      begin
        if @response_handler
          @bound_response_handler ||= @response_handler.bind self
          @bound_response_handler[@websocket]
        else
          raise NotImplementedError
        end
      rescue IOError => ioe
        if ioe.message == 'closed stream'
          debug "socket closed!"
          @websocket.close
          @base.websockets.delete @websocket
        else
          raise ioe
        end
      rescue => e
        error e.message
        ::STDERR.puts e.backtrace
        @connection.close
      end
    end

  end

end
