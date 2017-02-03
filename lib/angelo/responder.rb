module Angelo

  class Responder
    include Celluloid::Internals::Logger

    class << self

      attr_writer :default_headers

      # top-level setter
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

    end

    attr_accessor :connection, :mustermann, :request
    attr_writer :base

    def initialize method, &block
      @method, @response_handler = method, block
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
      Angelo.log @method, @connection, @request, nil, type, err_msg.size
      @connection.respond type, headers, err_msg
      @connection.close
      error _error if report
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

    # route handler helper
    def content_type type
      case type
      when :json
        headers CONTENT_TYPE_HEADER_KEY => JSON_TYPE
      when :html
        headers CONTENT_TYPE_HEADER_KEY => HTML_TYPE
      when :js
        headers CONTENT_TYPE_HEADER_KEY => JS_TYPE
      when :xml
        headers CONTENT_TYPE_HEADER_KEY => XML_TYPE
      else
        raise ArgumentError.new "invalid content_type: #{type}"
      end
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

    def respond_with? type
      case headers[CONTENT_TYPE_HEADER_KEY]
      when JSON_TYPE
        type == :json
      when EVENT_STREAM_TYPE
        type == :event_stream
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

      else
        if respond_with? :json and @body.respond_to? :to_json
          @body = @body.to_json
          raise "uhhh? #{@body}" unless String === @body
        else
          unless @chunked and @body.respond_to? :each
            raise RequestError.new "what is this? #{@body}"
          end
        end
      end

      status ||= @redirect.nil? ? :ok : @redirect[1]
      headers LOCATION_HEADER_KEY => @redirect[0] if @redirect

      if @chunked
        Angelo.log @method, @connection, @request, nil, status
        @request.respond status, headers
        err = nil
        begin
          @body.each do |r|
            r = r.to_json + NEWLINE if respond_with? :json
            @request << r
          end
        rescue => e
          err = e
        ensure
          @request.finish_response
          raise err if err
        end
      else
        size = @body.nil? ? 0 : @body.size
        Angelo.log @method, @connection, @request, nil, status, size
        @request.respond status, headers, @body
      end

    rescue => e
      handle_error e, :internal_server_error
    end

    def redirect url, permanent = false
      @redirect = [url, permanent ? :moved_permanently : :found]
      nil
    end

    def redirect! url
      redirect url, true
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
