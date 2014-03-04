$:.unshift File.expand_path '../../../lib', __FILE__

require 'bundler'
Bundler.require :default, :development, :test
require 'angelo'
require 'angelo/rspec/helpers'
Celluloid.logger.level = ::Logger::ERROR
include Angelo::RSpec::Helpers

APP_ROOT = File.expand_path '../angelo', __FILE__
