require 'openssl'
require 'mime-types'

module Angelo

  class Server < Reel::Server::HTTP
    extend Forwardable
    include Celluloid::Logger

    def_delegators :@base, :websockets, :sses

    def initialize base, host = '127.0.0.1', port = 4567
      @base = base
      info "Angelo #{VERSION}"
      info "listening on #{host}:#{port}"
      super host, port, &method(:on_connection)
    end

    def on_connection connection
      # RubyProf.resume
      responses = []

      connection.each_request do |request|
        meth = request.websocket? ? :websocket : request.method.downcase.to_sym
        responses << dispatch!(meth, connection, request)
      end

      responses.each do |response|
        if response.is_a?(Responder) and on_close = response.on_close
          on_close.call
        end
      end
      # RubyProf.pause
    end

    def self.define_task name, &action
      define_method name, &action
    end

    def self.remove_task name
      remove_method name
    end

    private

    def dispatch! meth, connection, request
      if staticable?(meth) and lp = @base.local_path(request.path)
        static! meth, connection, request, lp
      else
        route! meth, connection, request
      end
    rescue URI::InvalidURIError => e
      Angelo.log connection, request, nil, :bad_request
      connection.respond :bad_request, DEFAULT_RESPONSE_HEADERS, e.message
    end

    def route! meth, connection, request
      if @base.routes[meth] and rs = @base.routes[meth][request.path]
        responder = rs.dup
        responder.base = @base.new responder
        responder.connection = connection
        responder.request = request
        return responder
      else
        Angelo.log connection, request, nil, :not_found
        connection.respond :not_found, DEFAULT_RESPONSE_HEADERS, NOT_FOUND
      end
    end

    def staticable? meth
      STATICABLE.include? meth
    end

    def static! meth, connection, request, local_path
      etag = etag_for local_path
      if request.headers[IF_NONE_MATCH_HEADER_KEY] == etag
        Angelo.log connection, request, nil, :not_modified, 0
        connection.respond :not_modified
      else
        headers = {

          # Content-Type
          #
          CONTENT_TYPE_HEADER_KEY =>
            (MIME::Types.type_for(File.extname(local_path))[0].content_type rescue HTML_TYPE),

          # Content-Length
          #
          CONTENT_LENGTH_HEADER_KEY => File.size(local_path),

          # ETag
          #
          ETAG_HEADER_KEY => etag

        }
        Angelo.log connection, request, nil, :ok, headers[CONTENT_LENGTH_HEADER_KEY]
        connection.respond :ok, headers, (meth == :head ? nil : File.read(local_path))
      end
    end

    def etag_for local_path
      fs = File::Stat.new local_path
      OpenSSL::Digest::SHA.hexdigest fs.ino.to_s + fs.size.to_s + fs.mtime.to_s
    end

    def sse_event *a; Base.sse_event *a; end
    def sse_message *a; Base.sse_message *a; end

  end

end
