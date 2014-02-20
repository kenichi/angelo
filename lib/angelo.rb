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

  ROUTABLE = [:get, :post, :put, :delete, :socket]
  HTTPABLE = [:get, :post, :put, :delete]

  CONTENT_TYPE_HEADER_KEY = 'Content-Type'

  HTML_TYPE = 'text/html'
  JSON_TYPE = 'application/json'
  FORM_TYPE = 'application/x-www-form-urlencoded'

  DEFAULT_ADDR = '127.0.0.1'
  DEFAULT_PORT = 4567

  DEFAULT_RESPONSE_HEADERS = {
    CONTENT_TYPE_HEADER_KEY => HTML_TYPE
  }

  NOT_FOUND = 'Not Found'

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
