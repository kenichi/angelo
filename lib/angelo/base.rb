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
          debug "got websocket request..."
          route_websocket connection, request
        else
          route_request connection, request
        end
      end
    end

    def route_request connection, request
      route! request.method.downcase.to_sym, connection, request
    end

    def route_websocket connection, request
      route! :socket, connection, request
    end

    def route! meth, connection, request
      rs = self.class.routes[meth][request.path]
      if rs
        responder = rs.dup
        responder.base = self
        responder.connection = connection
        responder.request = request
      else
        connection.respond :not_found, DEFAULT_RESPONSE_HEADERS, NOT_FOUND
      end
    end
    private :route!

    class << self

      def routes
        @routes ||= {}
        [:get, :post, :put, :delete, :options, :socket].each do |m|
          @routes[m] ||= {}
        end
        @routes
      end

      def before &block
        @before = Responder.compile! :before, &block
      end

      def after &block
        @after = Responder.compile! :after, &block
      end

      [:get, :post, :put, :delete, :options].each do |m|
        define_method m do |path, &block|
          routes[m][path] = Responder.new @before, @after, &block
        end
      end

      def socket path, &block
        routes[:socket][path] = WebsocketResponder.new &block
      end

      def websockets
        @websockets ||= []
        @websockets.reject! &:closed?
        @websockets
      end

    end

    def websockets; self.class.websockets; end

  end

end
