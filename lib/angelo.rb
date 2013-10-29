require 'reel'
require 'json'
require 'pry'

module Angelo

  GET =     'GET'.freeze
  POST =    'POST'.freeze
  PUT =     'PUT'.freeze
  DELETE =  'DELETE'.freeze
  OPTIONS = 'OPTIONS'.freeze

  CONTENT_TYPE_HEADER_KEY = 'Content-Type'.freeze

  HTML_TYPE = 'text/html'.freeze
  JSON_TYPE = 'application/json'.freeze
  FORM_TYPE = 'application/x-www-form-urlencoded'.freeze

  DEFAULT_RESPONSE_HEADERS = {
    CONTENT_TYPE_HEADER_KEY => HTML_TYPE
  }


  NOT_FOUND = 'Not Found'.freeze

end

require 'angelo/version'
require 'angelo/base'
require 'angelo/params_parser'
require 'angelo/responder'
require 'angelo/responder/websocket'
