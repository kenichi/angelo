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
        define_method m do |path, opts = {}, &block|
          path = ::Mustermann.new path, opts
          routes[m][path] = Responder.new &block
        end
      end

      def websocket path, &block
        path = ::Mustermann.new path
        super path, &block
      end

      def eventsource path, headers = nil, &block
        path = ::Mustermann.new path
        super path, headers, &block
      end

      def routes
        @routes ||= Hash.new{|h,k| h[k] = RouteMap.new}
      end

      def filter_by which, path, meth
        pattern = ::Mustermann.new path
        filters[which][pattern] ||= []
        filters[which][pattern] << meth
      end

    end

    def params
      @params ||= super.merge mustermann.params(request.path)
    end

    def filter which
      fs = self.class.filters[which][:default].dup
      self.class.filters[which].each do |pattern, f|
        if ::Mustermann === pattern and pattern.match request.path
          fs << [f, pattern]
        end
      end
      fs.each do |f|
        case f
        when UnboundMethod
          f.bind(self).call
        when Array
          @pre_filter_params = params
          @params = @pre_filter_params.merge f[1].params(request.path)
          f[0].each {|filter| filter.bind(self).call}
          @params = @pre_filter_params
        end
      end
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
