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
    while msg = s.read
      5.times {
        s.write({foo: "bar", baz: 123, bat: false}.to_json)
      }
      s.write foo.to_json
    end
  end

end

Foo.run
