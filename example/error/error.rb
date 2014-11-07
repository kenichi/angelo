#!/usr/bin/env ruby

$:.unshift File.expand_path '../../../lib', __FILE__

Bundler.require :default, :development

require 'angelo'
require 'angelo/tilt/erb'
require 'angelo/mustermann'

class Bar < Angelo::Base
  include Angelo::Tilt::ERB
  include Angelo::Mustermann

  OK = {status: 'ok'}
  ERROR = {type: 'foo', message: 'bar'}

  content_type :json

  before '/json' do
    case params[:error]
    when 'ok'
      raise RequestError.new sse_event(:error, ERROR), 200
    when 'true'
      raise RequestError.new sse_event(:error, ERROR)
    end
  end

  get '/' do
    content_type :html
    erb :index
  end

  eventsource '/json' do |sse|
    5.times do
      sse.event :ok, OK.merge(time: Time.now.to_i)
      sleep 1
    end
    sse.event :close
  end

end

Bar.run!
