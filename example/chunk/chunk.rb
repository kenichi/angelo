#!/usr/bin/env ruby

$:.unshift File.expand_path '../../../lib', __FILE__

Bundler.require :default, :development

require 'angelo'
require 'angelo/tilt/erb'
require 'angelo/mustermann'

class Chunk < Angelo::Base
  include Angelo::Tilt::ERB
  include Angelo::Mustermann

  @@report_errors = true

  get '/' do
    erb :index
  end

  get '/chunk' do
    content_type :json
    chunked_response do |r|
      5.times do
        r[{time: Time.now.to_i}]
        sleep 0.5
      end
    end
  end

end

Chunk.run unless $0 == 'irb'
