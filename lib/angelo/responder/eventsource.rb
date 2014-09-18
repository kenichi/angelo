module Angelo
  class Responder
    class Eventsource < Responder

      def initialize _headers = nil, &block
        headers _headers if _headers
        super &block
      end

      def request= request
        @params = nil
        @request = request
        handle_request
      end

      def handle_request
        begin
          if @response_handler
            @base.before if @base.respond_to? :before
            @body = catch(:halt) { @base.eventsource &@response_handler.bind(@base) }
            if HALT_STRUCT === @body
              raise RequestError.new 'unknown sse error' unless @body.body == :sse
            end

            # TODO any real reason not to run afters with SSE?
            # @base.after if @base.respond_to? :after

            respond
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

      def respond
        Angelo.log @connection, @request, nil, :ok
        @request.respond 200, headers, nil
      end

    end
  end
end
