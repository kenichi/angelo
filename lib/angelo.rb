require 'reel'
require 'json'

# require 'ruby-prof'
#
# RubyProf.start
# RubyProf.pause

module Angelo

  GET =     'GET'
  POST =    'POST'
  PUT =     'PUT'
  DELETE =  'DELETE'
  OPTIONS = 'OPTIONS'

  ROUTABLE = [:get, :post, :put, :delete, :websocket]
  HTTPABLE = [:get, :post, :put, :delete]
  STATICABLE = [:get, :head]

  CONTENT_TYPE_HEADER_KEY = 'Content-Type'
  CONTENT_DISPOSITION_HEADER_KEY = 'Content-Disposition'
  CONTENT_LENGTH_HEADER_KEY = 'Content-Length'
  DEFAULT_CONTENT_DISPOSITION = 'attachment'
  ETAG_HEADER_KEY = 'ETag'
  IF_NONE_MATCH_HEADER_KEY = 'If-None-Match'
  LOCATION_HEADER_KEY = 'Location'

  HTML_TYPE = 'text/html'
  JSON_TYPE = 'application/json'
  FORM_TYPE = 'application/x-www-form-urlencoded'
  FILE_TYPE = 'application/octet-stream'
  JS_TYPE =   'text/javascript'

  DEFAULT_ADDR = '127.0.0.1'
  DEFAULT_PORT = 4567

  DEFAULT_VIEW_DIR = 'views'
  DEFAULT_PUBLIC_DIR = 'public'

  DEFAULT_LOG_LEVEL = ::Logger::INFO
  DEFAULT_RESPONSE_LOG_LEVEL = :info

  DEFAULT_RESPONSE_HEADERS = {
    CONTENT_TYPE_HEADER_KEY => HTML_TYPE
  }

  NOT_FOUND = 'Not Found'

  LOG_FORMAT = '%s - - "%s %s%s HTTP/%s" %d %s'

  DEFAULT_PING_TIME = 30

  UNDERSCORE = '_'
  DASH = '-'
  EMPTY_STRING = ''

  HALT_STRUCT = Struct.new :status, :body

  class << self

    attr_writer :response_log_level

    def response_log_level
      @response_log_level ||= DEFAULT_RESPONSE_LOG_LEVEL
    end

  end

  def self.log connection, request, socket, status, body_size = '-'

    remote_ip = ->{
      if socket.nil?
        connection.remote_ip rescue 'unknown'
      else
        socket.peeraddr(false)[3]
      end
    }

    Celluloid::Logger.__send__ Angelo.response_log_level, LOG_FORMAT % [
      remote_ip[],
      request.method,
      request.path,
      request.query_string.nil? ? nil : '?'+request.query_string,
      request.version,
      Symbol === status ? HTTP::Response::SYMBOL_TO_STATUS_CODE[status] : status,
      body_size
    ]

  end

  class RequestError < Reel::RequestError

    attr_accessor :type
    alias_method :code=, :type=

    def initialize msg = nil, type = nil
      case msg
      when Hash
        @msg_hash = msg
      else
        super(msg)
      end
      self.type = type if type
    end

    def type
      @type ||= :bad_request
    end

    def message
      @msg_hash || super
    end

  end

end

require 'angelo/version'
require 'angelo/params_parser'
require 'angelo/server'
require 'angelo/base'
require 'angelo/stash'
require 'angelo/responder'
require 'angelo/responder/websocket'

# trap "INT" do
#   result = RubyProf.stop
#   printer = RubyProf::MultiPrinter.new(result)
#   printer.print(path: './profiler', profile: 'foo')
#   exit
# end
