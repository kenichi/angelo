#!/usr/bin/env ruby

$:.unshift File.expand_path '../../../lib', __FILE__

Bundler.require :default, :development

require 'angelo'
require 'angelo/tilt/erb'
require 'angelo/mustermann' unless RUBY_PLATFORM == 'java'

class Bar < Angelo::Base
  include Angelo::Tilt::ERB
  include Angelo::Mustermann unless RUBY_PLATFORM == 'java'

  HEART = '❤️'
  CORS = { 'Access-Control-Allow-Origin' => '*',
           'Access-Control-Allow-Methods' => 'GET, POST',
           'Access-Control-Allow-Headers' => 'Accept, Authorization, Content-Type, Origin' }
  @@ping_time = 3
  @@hearting = false
  @@beating = false
  @@report_errors = true
  @@log_level = Logger::DEBUG

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
    if params[:sse]
      eventsource do |client|
        sses[params[:event].to_sym] << client if params[:event]
        if params[:time]
          loop do
            data = {time: Time.now}.to_json
            client.write sse_event(:time, data)
            sleep 1
          end
        end
      end
    else
      'boring'
    end
  end

  post '/sse_event' do
    sses[params[:event].to_sym].event hello: 'there', fools: 'you!'
  end

  post '/sse_msg' do
    sses[params[:context].to_sym].message 'this is a message!'
  end

  eventsource '/meh' do |client|
    sses[:meh] << client
    loop do
      data = {time: Time.now}.to_json
      client.write sse_event(:time, data)
      sleep 1
    end
  end

  post '/sse_meh' do
    sses[:meh].message params[:meh]
  end

  options '/cors' do
    headers CORS
    nil
  end

  get '/cors' do
    headers CORS
    'hi there'
  end

  eventsource '/sse_cors', CORS do |c|
    c.write sse_event :cors, 'cors!'
    c.close
  end

end

Bar.supervise unless $0 == 'irb'
