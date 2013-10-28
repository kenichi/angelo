$:.push File.expand_path '../lib', __FILE__

require 'angelo'

class Foo < Angelo::Base

  def pong; 'pong'; end
  def foo; params[:foo]; end

  get '/ping' do
    pong
  end

  post '/foo' do
    foo
  end

  post '/bar' do
    params.to_json
  end

  socket '/ws' do |s|

    5.times {
      s.write({foo: "bar", baz: 123, bat: false}.to_json)
      sleep 1
    }

  end

end

Foo.run
