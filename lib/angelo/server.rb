require 'openssl'
require 'mime-types'

module Angelo

  class Server < Reel::Server::HTTP
    extend Forwardable
    include Celluloid::Internals::Logger

    def_delegators :@base, :websockets, :sses

    attr_reader :base

    def initialize base, addr = nil, port = nil, options = {}
      @base = base
      addr ||= @base.addr
      port ||= @base.port
      info "Angelo #{VERSION}"
      info "listening on #{addr}:#{port}"
      super addr, port, options, &method(:on_connection)
    end

    def on_connection connection
      # RubyProf.resume
      responders = []

      connection.each_request do |request|
        meth = request.websocket? ? :websocket : request.method.downcase.to_sym
        responder = dispatch! meth, connection, request
        responders << responder if responder and responder.respond_to? :on_close
      end

      responders.each &:on_close
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
      Angelo.log meth, connection, request, nil, :bad_request
      connection.respond :bad_request, DEFAULT_RESPONSE_HEADERS, e.message
    end

    def post_override! meth, request
      if meth == :post and request.headers.has_key? POST_OVERRIDE_REQUEST_HEADER_KEY
        new_meth = request.headers[POST_OVERRIDE_REQUEST_HEADER_KEY].downcase.to_sym
        meth = new_meth if POST_OVERRIDABLE.include? new_meth
      end
      meth
    rescue
      meth
    end

    def route! meth, connection, request
      meth = post_override! meth, request
      if rs = @base.routes[meth][request.path]
        responder = rs.dup
        responder.reset!
        responder.base = @base.new responder
        responder.connection = connection
        responder.request = request
        responder.handle_request
        responder
      else
        Angelo.log meth, connection, request, nil, :not_found
        connection.respond :not_found, DEFAULT_RESPONSE_HEADERS, NOT_FOUND
      end
    end

    def staticable? meth
      STATICABLE.include? meth
    end

    def static! meth, connection, request, local_path
      etag = etag_for local_path
      if request.headers[IF_NONE_MATCH_HEADER_KEY] == etag
        Angelo.log meth, connection, request, nil, :not_modified, 0
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
        Angelo.log meth, connection, request, nil, :ok, headers[CONTENT_LENGTH_HEADER_KEY]
        connection.respond :ok, headers, (meth == :head ? nil : File.read(local_path))
      end
    end

    def etag_for local_path
      fs = File::Stat.new local_path
      OpenSSL::Digest::SHA1.hexdigest fs.ino.to_s + fs.size.to_s + fs.mtime.to_s
    end

    def sse_event *a; Base.sse_event *a; end
    def sse_message *a; Base.sse_message *a; end

  end

end
