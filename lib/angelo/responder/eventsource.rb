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
            @base.filter :before
            @body = catch(:halt) { @base.eventsource &@response_handler.bind(@base) }
            if HALT_STRUCT === @body
              raise RequestError.new 'unknown sse error' unless @body.body == :sse
            end

            # TODO any real reason not to run afters with SSE?
            # @base.filter :after

            respond
          else
            raise NotImplementedError
          end
        rescue IOError => ioe
          warn "#{ioe.class} - #{ioe.message}"
        rescue RequestError => re
          handle_error re, re.type
        rescue => e
          handle_error e
        end
      end

      def respond
        Angelo.log @connection, @request, nil, :ok
        @request.respond 200, headers, nil
      end

    end
  end
end
