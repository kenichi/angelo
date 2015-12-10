module Angelo

  class Responder
    include Celluloid::Logger

    class << self

      attr_writer :default_headers, :default_content_type

      # top-level setter
      def content_type type_or_mime, handler_class=nil, &block
        @default_content_type = ContentTypeHandler.fetch_or_create(type_or_mime,
                                                                   handler_class,
                                                                   &block)
        set_default
      end

      def default_headers
        @default_headers ||= set_default(DEFAULT_RESPONSE_HEADERS)
        @default_headers
      end

      def set_default(defaults=default_headers)
        @default_headers = defaults.merge(CONTENT_TYPE_HEADER_KEY =>
                                          default_content_type.mime)
      end

      def default_content_type
        @default_content_type ||= ContentTypeHandler[DEFAULT_CONTENT_TYPE]
        @default_content_type 
      end
    end

    attr_accessor :connection, :mustermann, :request
    attr_writer :base

    def initialize &block
      @response_handler = block
    end

    def reset!
      @params = nil
      @redirect = nil
      @body = nil
      @request = nil
    end

    def handle_request
      if @response_handler
        @base.filter :before
        @body = catch(:halt) { @base.instance_exec(&@response_handler) || EMPTY_STRING }

        # TODO any real reason not to run afters with SSE?
        case @body
        when HALT_STRUCT
          @base.filter :after if @body.body != :sse
        else
          @base.filter :after
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
      content_type_handler.handle_error(_error)
    end

    def headers hs = nil
      @headers ||= self.class.default_headers.dup
      @headers.merge! hs if hs
      @headers
    end

    # route handler helper
    def content_type type_or_mime, handler_class=nil, &block
      @content_type_handler = ContentTypeHandler.fetch_or_create(type_or_mime,
                                                                 handler_class,
                                                                 &block)
      headers CONTENT_TYPE_HEADER_KEY => content_type_handler.mime
    end

    def content_type_handler
      @content_type_handler ||= self.class.default_content_type
    end

    def transfer_encoding *encodings
      encodings.flatten.each do |encoding|
        case encoding
        when :chunked
          @chunked = true
          headers transfer_encoding: :chunked
        # when :compress, :deflate, :gzip, :identity
        else
          raise ArgumentError.new "invalid transfer_conding: #{encoding}"
        end
      end
    end

    def respond
      status = nil
      case @body
      when HALT_STRUCT
        status = @body.status
        @body = @body.body
        @body = nil if @body == :sse
        if status != :ok || status < 200 && status >= 300
          @body = content_type_handler.handle_error(@body)
        end
      when NilClass
        @body = EMPTY_STRING
      else
        if @chunked and !@body.respond_to? :each
          raise RequestError.new "what is this? #{@body}"
        end
      end

      status ||= @redirect.nil? ? :ok : :moved_permanently
      headers LOCATION_HEADER_KEY => @redirect if @redirect

      if @chunked
        Angelo.log @connection, @request, nil, status
        @request.respond status, headers
        err = nil
        begin
          @body.each do |r|
            @request << content_type_handler.handle(r)
          end
        rescue => e
          err = e
        ensure
          @request.finish_response
          raise err if err
        end
        return
      else
        @body = content_type_handler.handle(@body)
      end
      
      size = @body.nil? ? 0 : @body.size
      Angelo.log @connection, @request, nil, status, size
      @request.respond status, headers, @body

    rescue => e
      handle_error e, :internal_server_error
    end

    def redirect url
      @redirect = url
      nil
    end

    def on_close= on_close
      raise ArgumentError.new unless Proc === on_close
      @on_close = on_close
    end

    def on_close
      @on_close[] if @on_close
    end
  end
end
