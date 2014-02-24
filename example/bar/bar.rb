#!/usr/bin/env ruby

$:.unshift File.expand_path '../../../lib', __FILE__

Bundler.require :default, :development

require 'angelo'
require 'angelo/tilt/erb'

class Foo < Angelo::Base
  include Angelo::Tilt::ERB

  get '/' do
    'hi'
  end

  socket '/' do |ws|
  end

end

Foo.run unless $0 == 'irb'
