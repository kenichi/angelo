require_relative '../spec_helper'
require 'angelo/tilt/erb'

ROOT = File.expand_path '..', __FILE__

describe Angelo::Base do
  describe Angelo::Tilt::ERB do

    define_app do

      include Angelo::Tilt::ERB

      @root = ROOT

      def set_vars
        @title = 'test'
        @foo = params[:foo]
      end

      get '/' do
        set_vars
        erb :index, locals: {bar: 'bat'}
      end

      get '/no_layout' do
        set_vars
        erb :index, layout: false, locals: {bar: 'bat'}
      end

    end

    it 'renders templates with layout' do
      get '/', foo: 'asdf'
      expected = <<HTML
<!doctype html>
<html>
  <head>
    <title>test</title>
  </head>
  <body>
    foo - asdf
locals :bar - bat

  </body>
</html>
HTML
      last_response_should_be_html expected
    end

    it 'renders templates without layout' do
      get '/no_layout', foo: 'asdf'
      expected = <<HTML
foo - asdf
locals :bar - bat
HTML
      last_response_should_be_html expected
    end

  end
end
