require 'reel'
require 'json'

# require 'ruby-prof'
#
# RubyProf.start
# RubyProf.pause

module Angelo

  GET =     'GET'.freeze
  POST =    'POST'.freeze
  PUT =     'PUT'.freeze
  DELETE =  'DELETE'.freeze
  OPTIONS = 'OPTIONS'.freeze

  ROUTABLE = [:get, :post, :put, :delete, :options, :socket]
  HTTPABLE = [:get, :post, :put, :delete, :options]

  CONTENT_TYPE_HEADER_KEY = 'Content-Type'.freeze

  HTML_TYPE = 'text/html'.freeze
  JSON_TYPE = 'application/json'.freeze
  FORM_TYPE = 'application/x-www-form-urlencoded'.freeze

  DEFAULT_ADDR = '127.0.0.1'.freeze
  DEFAULT_PORT = 4567

  DEFAULT_RESPONSE_HEADERS = {
    CONTENT_TYPE_HEADER_KEY => HTML_TYPE
  }

  NOT_FOUND = 'Not Found'.freeze

end

require 'angelo/version'
require 'angelo/params_parser'
require 'angelo/server'
require 'angelo/base'
require 'angelo/responder'
require 'angelo/responder/websocket'

# trap "INT" do
#   result = RubyProf.stop
#   printer = RubyProf::MultiPrinter.new(result)
#   printer.print(path: './profiler', profile: 'foo')
#   exit
# end
