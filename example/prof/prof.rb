$:.unshift File.expand_path '../../../lib', __FILE__

require 'angelo'

class Prof < Angelo::Base

  log_level = Logger::ERROR

  get '/' do
    Angelo::EMPTY_STRING
  end

end

Prof.run!
