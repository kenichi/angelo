#!/usr/bin/env ruby

$:.unshift File.expand_path '../../../lib', __FILE__

Bundler.require :default, :development

require 'angelo'
require 'angelo/tilt/erb'

class Foo < Angelo::Base
  include Angelo::Tilt::ERB

  HEART = '<3'
  @@ping_time = 3
  @@hearting = false

  get '/' do
    erb :index
  end

  socket '/' do |ws|
    websockets << ws
    ws.on_message do |msg|
      ws.write msg
    end
  end

  on_pong do
    puts "got pong!"
  end

  socket '/hearts' do |ws|
    async :hearts unless @@hearting
    websockets[:hearts] << ws
  end

  async :hearts do
    @@hearting = true
    every(10){ websockets[:hearts].each {|ws| ws.write HEART } }
  end

end

Foo.run unless $0 == 'irb'
