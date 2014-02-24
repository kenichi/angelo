module Angelo

  class Server < Reel::Server
    include Celluloid::Logger

    def initialize base, host = '127.0.0.1', port = 4567
      @base = base
      info "Angelo #{VERSION}"
      info "listening on #{host}:#{port}"
      super host, port, &method(:on_connection)
    end

    def on_connection connection
      # RubyProf.resume
      connection.each_request do |request|
        if request.websocket?
          route_websocket connection, request
        else
          route_request connection, request
        end
      end
      # RubyProf.pause
    end

    private

    def route_request connection, request
      route! request.method.downcase.to_sym, connection, request
    end

    def route_websocket connection, request
      route! :socket, connection, request
    end

    def route! meth, connection, request
      rs = @base.routes[meth][request.path]
      if rs
        responder = rs.dup
        responder.base = @base.new
        responder.connection = connection
        responder.request = request
      else
        Responder.common_log connection, request, HTTP::Response::SYMBOL_TO_STATUS_CODE[:not_found]
        connection.respond :not_found, DEFAULT_RESPONSE_HEADERS, NOT_FOUND
      end
    end

  end

end
