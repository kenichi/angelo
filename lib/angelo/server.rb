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
        meth = request.websocket? ? :socket : request.method.downcase.to_sym
        route! meth, connection, request
      end
      # RubyProf.pause
    end

    private

    def route! meth, connection, request
      rs = @base.routes[meth][request.path]
      if rs
        responder = rs.dup
        responder.base = @base.new
        responder.connection = connection
        responder.request = request
      else
        Angelo.log connection, request, nil, :not_found
        connection.respond :not_found, DEFAULT_RESPONSE_HEADERS, NOT_FOUND
      end
    end

  end

end
