#!/usr/bin/env ruby

$:.unshift File.expand_path '../../../lib', __FILE__

Bundler.require :default, :development

require 'angelo'
require 'angelo/tilt/erb'
require 'angelo/mustermann'

class Foo < Angelo::Base
  include Angelo::Tilt::ERB
  include Angelo::Mustermann

  HEART = '<3'
  @@ping_time = 3
  @@hearting = false

  get '/' do
    redirect '/index'
  end

  get '/index' do
    erb :index
  end

  post '/in/:sec/sec/:thing' do
    f = future :in_sec, params[:sec], params[:thing]
    f.value
  end

  task :in_sec do |sec, msg|
    sleep sec.to_i
    msg
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

  task :hearts do
    @@hearting = true
    every(10){ websockets[:hearts].each {|ws| ws.write HEART } }
  end

end

Foo.run unless $0 == 'irb'
