require 'mustermann'

module Angelo

  module Mustermann

    # hrm, sneaky
    #
    def self.included base
      base.extend ClassMethods
      base.class_eval do
        def_delegator :@responder, :mustermann
      end

      [Responder, WebsocketResponder].each do |res|
        res.class_eval do
          attr_accessor :mustermann
        end
      end
    end

    module ClassMethods

      HTTPABLE.each do |m|
        define_method m do |path, &block|
          path = ::Mustermann.new path
          routes[m][path] = Responder.new &block
        end
      end

      def routes
        @routes ||= {}
        ROUTABLE.each do |m|
          @routes[m] ||= RouteMap.new
        end
        @routes
      end

    end

    def params
      @params ||= super.merge mustermann.params(request.path)
      @params
    end

    class RouteMap < Hash
      def [] route
        mustermann = keys.select {|k| k.match(route)}.first
        responder = fetch mustermann
        responder.mustermann = mustermann
        responder
      end
    end

  end
end
