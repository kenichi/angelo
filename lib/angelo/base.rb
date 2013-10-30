module Angelo

  class Base
    include ParamsParser
    include Celluloid::Logger

    extend Forwardable
    def_delegator :@responder, :request

    attr_accessor :responder

    class << self

      def compile! name, &block
        define_method name, &block
        method = instance_method name
        remove_method name
        method
      end

      def routes
        @routes ||= {}
        [:get, :post, :put, :delete, :options, :socket].each do |m|
          @routes[m] ||= {}
        end
        @routes
      end

      def before &block
        # @before = compile! :before, &block
        define_method :before, &block
      end

      def after &block
        # @after = compile! :after, &block
        define_method :after, &block
      end

      [:get, :post, :put, :delete, :options].each do |m|
        define_method m do |path, &block|
          routes[m][path] = Responder.new &block
        end
      end

      def socket path, &block
        routes[:socket][path] = WebsocketResponder.new &block
      end

      def websockets
        if @websockets.nil?
          @websockets = []
          def @websockets.each &block
            super do |ws|
              begin
                yield ws
              rescue Reel::SocketError => rse
                warn "#{rse.class} - #{rse.message}"
                delete ws
              end
            end
          end
        end
        @websockets.reject! &:closed?
        @websockets
      end

      def run host = '127.0.0.1', port = 4567
        @server = Angelo::Server.new self, host, port
        sleep
      end

    end

    def before; end;
    def after; end;

    def params
      @params ||= case request.method
                  when GET;  parse_query_string
                  when POST; parse_post_body
                  end
      @params
    end

    def websockets; self.class.websockets; end

  end

end
