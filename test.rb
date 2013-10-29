$:.push File.expand_path '../lib', __FILE__

require 'angelo'

class Foo < Angelo::Base

  TEST = {foo: "bar", baz: 123, bat: false}.to_json

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

  post '/emit' do
    websockets.each {|ws| ws.write TEST}
    params.to_json
  end

  socket '/ws' do |s|
    websockets << s
    while msg = s.read
      5.times { s.write TEST }
      s.write foo.to_json
    end
  end

end

Foo.run
