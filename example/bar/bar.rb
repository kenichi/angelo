#!/usr/bin/env ruby

$:.unshift File.expand_path '../../../lib', __FILE__

Bundler.require :default, :development

require 'angelo'
require 'angelo/tilt/erb'

class Foo < Angelo::Base
  include Angelo::Tilt::ERB

  get '/' do
    erb :index
  end

  socket '/' do |ws|
    debug "websocket connected! reading..."
    while msg = ws.read
      debug "msg: '#{msg}'"
      ws.write msg
    end
  end

end

Foo.run unless $0 == 'irb'
