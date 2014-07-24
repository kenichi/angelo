require 'date'

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

    attr_accessor :connection
    attr_reader :request
    attr_writer :base

    def initialize &block
      @response_handler = Base.compile! :request_handler, &block
    end

    def request= request
      @params = nil
      @redirect = nil
      @body = nil
      @request = request
      handle_request
    end

    def handle_request
      if @response_handler
        @base.before if @base.respond_to? :before
        @body = catch(:halt) { @response_handler.bind(@base).call || EMPTY_STRING }

        # TODO any real reason not to run afters with SSE?
        case @body
        when HALT_STRUCT
          if @body.body != :sse and @base.respond_to? :after
            @base.after
          end
        else
          @base.after if @base.respond_to? :after
        end

        respond
      else
        raise NotImplementedError
      end
    rescue JSON::ParserError => jpe
      handle_error jpe, :bad_request
    rescue FormEncodingError => fee
      handle_error fee, :bad_request
    rescue RequestError => re
      handle_error re, re.type
    rescue => e
      handle_error e
    end

    def handle_error _error, type = :internal_server_error, report = @base.report_errors?
      err_msg = error_message _error
      Angelo.log @connection, @request, nil, type, err_msg.size
      @connection.respond type, headers, err_msg
      @connection.close
      if report
        error "#{_error.class} - #{_error.message}"
        ::STDERR.puts _error.backtrace
      end
    end

    def error_message _error
      case
      when respond_with?(:json)
        { error: _error.message }.to_json
      else
        case _error.message
        when Hash
          _error.message.to_s
        else
          _error.message
        end
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
      when :js
        headers CONTENT_TYPE_HEADER_KEY => JS_TYPE
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
      status = nil
      case @body
      when HALT_STRUCT
        status = @body.status
        @body = @body.body
        @body = nil if @body == :sse
        if Hash === @body
          @body = {error: @body} if status != :ok or status < 200 && status >= 300
          @body = @body.to_json if respond_with? :json
        end

      when String
        JSON.parse @body if respond_with? :json # for the raises

      when Hash
        raise 'html response requires String' if respond_with? :html
        @body = @body.to_json if respond_with? :json

      when NilClass
        @body = EMPTY_STRING
      end

      status ||= @redirect.nil? ? :ok : :moved_permanently
      headers LOCATION_HEADER_KEY => @redirect if @redirect
      size = @body.nil? ? 0 : @body.size

      Angelo.log @connection, @request, nil, status, size
      @request.respond status, headers, @body
    rescue => e
      handle_error e, :internal_server_error
    end

    def redirect url
      @redirect = url
    end

  end

end
