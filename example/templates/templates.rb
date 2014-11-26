#!/usr/bin/env ruby

$:.unshift File.expand_path '../../../lib', __FILE__

Bundler.require :default, :development

require 'angelo'
require 'angelo/tilt/erb'

class Templates < Angelo::Base
  include Angelo::Tilt::ERB

  log_level Logger::DEBUG
  report_errors!

  before do
    @foo = 'foo'
  end

  get '/index.html' do
    erb :index, locals: {bar: 'bat'}
  end

  get '/index.js' do
    content_type :js
    erb :index, locals: {bar: 'bat'}
  end

  get '/index.json' do
    content_type :json
    erb :index, layout: :jason, locals: {bar: 'bat'}
  end

  get '/index.xml' do
    content_type :xml
    erb :index, locals: {bar: 'bat'}
  end

  get '/' do
    debug "Accept: #{request.headers['Accept']}"
    debug "template_type: #{template_type}"
    erb :index, locals: {bar: 'bat'}
  end

end

Templates.run! unless $0 == 'irb'
