module Angelo

  class Base < Reel::Server
    include Celluloid::Logger

    extend Forwardable
    attr_writer :responder
    def_delegators :@responder, :params

    def initialize host = '127.0.0.1', port = 4567
      info "Angelo listening on #{host}:#{port}"
      super host, port, &method(:on_connection)
    end

    def on_connection connection
      connection.each_request do |request|
        if request.websocket?
          route_websocket request
        else
          route_request connection, request
        end
      end
    end

    def route_request connection, request
      method = request.method.downcase.to_sym
      rs = self.class.routes

      if rs[method][request.path]
        responder = rs[method][request.path].dup
        responder.base = self
        responder.connection = connection
        responder.request = request
      else
        connection.respond :not_found, DEFAULT_RESPONSE_HEADERS, NOT_FOUND
      end
    end

    def route_websocket request
      rs = self.class.routes[:socket][request.path]
      rs[request.websocket] if rs
    end

    class << self

      def routes
        @routes ||= {}
        [:get, :post, :put, :delete, :options, :socket].each do |m|
          @routes[m] ||= {}
        end
        @routes
      end

      [:get, :post, :put, :delete, :options].each do |m|
        define_method m do |path, &block|
          routes[m][path] = Responder.new &block
        end
      end

      def socket path, &block
        routes[:socket][path] = block
      end

    end

  end

end
