module Angelo

  class Responder
    include Celluloid::Logger
    include ParamsParser

    class << self

      def symhash
        Hash.new {|hash,key| hash[key.to_s] if Symbol === key }
      end

      def compile! name, &block
        define_method name, &block
        method = instance_method name
        remove_method name
        method
      end

    end

    attr_writer :connection

    def initialize before = nil, after = nil, &block
      @before, @after = before, after
      @response_handler = Responder.compile! :request_handler, &block
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
          @before.bind(self).call if @before
          @body = @response_handler.bind(self).call || ''
          @after.bind(self).call if @after
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
        error e.message
        ::STDERR.puts e.backtrace
      end
    end

    def params
      @params ||= case @request.method
                  when GET;  parse_query_string
                  when POST; parse_post_body
                  end
      @params
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

    def method_missing meth, *args
      @base.__send__ meth, *args
    end

  end

end
