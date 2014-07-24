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

      [Responder, Responder::Websocket, Responder::Eventsource].each do |res|
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

      def websocket path, &block
        path = ::Mustermann.new path
        super path, &block
      end

      def eventsource path, &block
        path = ::Mustermann.new path
        super path, &block
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
    end

    class RouteMap

      def initialize
        @hash = Hash.new
      end

      def []= route, responder
        @hash[route] = responder
      end

      def [] route
        responder = nil
        if mustermann = @hash.keys.select {|k| k.match(route)}.first
          responder = @hash.fetch mustermann
          responder.mustermann = mustermann
        end
        responder
      end
    end

  end
end
