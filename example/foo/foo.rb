$:.unshift File.expand_path '../../../lib', __FILE__

require 'angelo'
require 'angelo/tilt/erb'

class Foo < Angelo::Base
  include Angelo::Tilt::ERB

  TEST = {foo: "bar", baz: 123, bat: false}.to_json

  def pong; 'pong'; end
  def foo; params[:foo]; end
  def time_ms; Time.now.to_f * 1000.0; end

  before do
    info "request: #{request.method} #{request.path}"
    @foo = request.path
    @timing = time_ms
  end

  after do
    info "timing: #{time_ms - @timing}ms"
  end

  get '/' do
    @name = params[:name]
    @host = request.headers['Host']
    erb :index, locals: {zzz: 'word'}
  end

  get '/ping' do
    debug "@foo: #{@foo}"
    pong
  end

  post '/foo' do
    foo
  end

  post '/bar' do
    content_type = :json
    params
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

Foo.run unless $0 == 'irb'
