module Angelo

  class Responder
    include Celluloid::Logger

    class << self

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
          @base.before
          @body = @response_handler.bind(@base).call || ''
          @base.after
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
      @headers ||= {}
      @headers.merge! hs if hs
      @headers
    end

    def content_type= type
      case type
      when :json
        headers CONTENT_TYPE_HEADER_KEY => JSON_TYPE
      else
        raise ArgumentError.new "invalid content_type: #{type}"
      end
    end

    def respond_with? type = nil
      eo = ->(t){ type && type == t or t}
      case headers[CONTENT_TYPE_HEADER_KEY]
      when JSON_TYPE
        eo[:json]
      else
        eo[:html]
      end
    end

    def respond
      @body = @body.to_json if respond_with? :json
      @connection.respond :ok, DEFAULT_RESPONSE_HEADERS.merge(headers), @body
    end

  end

end
