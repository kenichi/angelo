module Angelo

  class Responder
    include Celluloid::Logger

    class << self

      attr_writer :default_headers

      def content_type type
        dhs = self.default_headers
        case type
        when :json
          self.default_headers = dhs.merge CONTENT_TYPE_HEADER_KEY => JSON_TYPE
        when :html
          self.default_headers = dhs.merge CONTENT_TYPE_HEADER_KEY => HTML_TYPE
        else
          raise ArgumentError.new "invalid content_type: #{type}"
        end
      end

      def default_headers
        @default_headers ||= DEFAULT_RESPONSE_HEADERS
        @default_headers
      end

      def symhash
        Hash.new {|hash,key| hash[key.to_s] if Symbol === key }
      end

    end

    attr_writer :connection
    attr_reader :request

    def initialize &block
      @response_handler = Base.compile! :request_handler, &block
    end

    def base= base
      @base = base
      @base.responder = self
    end

    def request= request
      @params = nil
      @request = request
      handle_request
      respond
    end

    def handle_request
      begin
        if @response_handler
          @base.before if @base.respond_to? :before
          @body = @response_handler.bind(@base).call || ''
          @base.after if @base.respond_to? :after
        else
          raise NotImplementedError
        end
      rescue => e
        error_message = case
                        when respond_with?(:json)
                          { error: e.message }.to_json
                        else
                          e.message
                        end
        @connection.respond :internal_server_error, headers, error_message
        @connection.close
        error "#{e.class} - #{e.message}"
        ::STDERR.puts e.backtrace
      end
    end

    def headers hs = nil
      @headers ||= self.class.default_headers.dup
      @headers.merge! hs if hs
      @headers
    end

    def content_type type
      case type
      when :json
        headers CONTENT_TYPE_HEADER_KEY => JSON_TYPE
      when :html
        headers CONTENT_TYPE_HEADER_KEY => HTML_TYPE
      else
        raise ArgumentError.new "invalid content_type: #{type}"
      end
    end

    def respond_with? type
      case headers[CONTENT_TYPE_HEADER_KEY]
      when JSON_TYPE
        type == :json
      else
        type == :html
      end
    end

    def respond
      @body = @body.to_json if respond_with? :json
      @connection.respond :ok, headers, @body
    end

  end

end
