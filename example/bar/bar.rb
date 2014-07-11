#!/usr/bin/env ruby

$:.unshift File.expand_path '../../../lib', __FILE__

Bundler.require :default, :development

require 'angelo'
require 'angelo/tilt/erb'
require 'angelo/mustermann' unless RUBY_PLATFORM == 'java'

class Bar < Angelo::Base
  include Angelo::Tilt::ERB
  include Angelo::Mustermann unless RUBY_PLATFORM == 'java'

  HEART = '<3'
  @@ping_time = 3
  @@hearting = false
  @@beating = false
  @@report_errors = true

  after do
    puts "I'm after!"
  end

  get '/' do
    erb :index
    # redirect '/index'
  end

  get '/index' do
    erb :index
  end

  get '/pry' do
    binding.pry
    'pryed!'
  end

  get '/status' do
    content_type :json
    { hearting: @@hearting, beating: @@beating }
  end

  if RUBY_PLATFORM == 'java'
    post '/in/sec' do
      future(:in_sec, params[:sec], params[:thing]).value
    end
  else
    post '/in/:sec/sec/:thing' do
      future(:in_sec, params[:sec], params[:thing]).value
    end
  end

  task :in_sec do |sec, msg|
    sleep sec.to_i
    msg
  end

  websocket '/' do |ws|
    websockets << ws
    ws.on_message do |msg|
      ws.write msg
    end
  end

  on_pong do
    puts "got pong!"
  end

  websocket '/hearts' do |ws|
    async :hearts unless @@hearting
    websockets[:hearts] << ws
  end

  task :hearts do
    @@hearting = true
    every 1 do
      if websockets[:hearts].length == 0
        @@beating = false
      else
        @@beating = true
        websockets[:hearts].each {|ws| ws.write HEART }
      end
    end
  end

  get '/error' do
    raise RequestError.new '"foo" is a required parameter' unless params[:foo]
    params[:foo]
  end

  get '/error.json' do
    content_type :json
    raise RequestError.new foo: "required!"
    {foo: params[:foo]}
  end

  get '/not_found' do
    raise RequestError.new 'not found', 404
  end

  get '/halt' do
    halt 200, "everything's fine."
    raise RequestError.new "won't get here"
  end

  get '/raise' do
    raise 'this is another weird error!'
    'foo'
  end

  get '/sse' do
    eventsource do |client|
      loop do
        data = {time: Time.now}.to_json
        client.write "event: sse\ndata: #{data}\n\n"
        sleep 1
      end
    end
  end

end

Bar.run unless $0 == 'irb'
