Angelo
======

A Sinatra-esque DSL for Reel.

__SUPER ALPHA!__

### Quick example

```ruby
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
```

### Tilt / ERB

To make `erb` available in route blocks

1. add `tilt` to your `Gemfile`:

```ruby
gem 'tilt'
```

2. require `angelo/tilt/erb`
3. include `Angelo::Tilt::ERB` in your app

```ruby
class Foo < Angelo::Base
  include Angelo::Tilt::ERB

  @@views = 'some/other/path' # defaults to './views'

  get '/' do
    erb :index
  end

end
```

### License

see LICENSE
