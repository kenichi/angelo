module Angelo
  class ContentTypeHandler
    attr_accessor :type, :mime

    class << self
      def []=(type, handler)
        @handlers ||= {}
        @handlers[type] = handler
      end

      def [](type)
        @handlers ||= {}
        @handlers[type]
      end
      
      def fetch_or_create(type_or_mime, handler_class, &block)
        case type_or_mime
        when String
          ContentTypeHandler.new(nil,
                                 type_or_mime,
                                 handler_class,
                                 &block)
        when Symbol
          ContentTypeHandler[type_or_mime] ||
            raise(ArgumentError, "invalid content type: #{type}")
        end
      end
    end

    def initialize(type, mime, handler_class=nil, &block)
      @type, @mime = type, mime
      @handler = case
                 when block_given?
                   block
                 when handler_class
                   handler_class.new
                 end
      ContentTypeHandler[type] = self
    end

    def handle(body)
      case @handler
      when Proc
        @handler.call(body)
      when NilClass
        body
      else
        @handler.handle(body)
      end
    end

    def handle_error(error)
      if @handler.respond_to?(:handle_error)
        @handler.handle_error(error)
      else
        case error
        when RequestError
          handle(error.message.to_s)
        else
          handle(error.to_s)
        end
      end
    end
  end
end
