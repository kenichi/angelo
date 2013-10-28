require 'reel'
require 'json'
require 'pry'

module Angelo

  GET =     'GET'.freeze
  POST =    'POST'.freeze
  PUT =     'PUT'.freeze
  DELETE =  'DELETE'.freeze
  OPTIONS = 'OPTIONS'.freeze

  DEFAULT_RESPONSE_HEADERS = {
    'Content-Type' => 'text/html'
  }
  NOT_FOUND = 'Not Found'.freeze

end

require 'angelo/base'
require 'angelo/responder'
