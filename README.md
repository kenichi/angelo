Angelo
======

[![Build Status](https://travis-ci.org/kenichi/angelo.png?branch=master)](https://travis-ci.org/kenichi/angelo)

A [Sinatra](https://github.com/sinatra/sinatra)-esque DSL for [Reel](https://github.com/celluloid/reel).

### Notes/Features

* "easy" websocket support via `socket '/path' do |s|` route handler
* "easy" websocket stashing via `websockets` helper
* no rack/rack-style params
* optional tilt/erb support
* optional mustermann support

Lots of work left to do!

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
    websockets[:emit_test].each {|ws| ws.write TEST}
    params.to_json
  end

  socket '/ws' do |ws|
    websockets[:emit_test] << ws
    while msg = ws.read
      5.times { ws.write TEST }
      ws.write foo.to_json
    end
  end

  post '/other' do
    websockets[:other].each {|ws| ws.write TEST}
  end

  socket '/other/ws' do |ws|
    websockets[:other] << ws
  end

end

Foo.run
```

### [Tilt](https://github.com/rtomayko/tilt) / ERB

To make `erb` available in route blocks

1. add `tilt` to your `Gemfile`: `gem 'tilt'`
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

### [Mustermann](https://github.com/rkh/mustermann)

To make routes blocks match path with Mustermann patterns

1. be using ruby &gt;=2.0.0
2. add 'mustermann' to to your `Gemfile`: `platform(:ruby_20){ gem 'mustermann' }`
3. require `angelo/mustermann`
4. include `Angelo::Mustermann` in your app

```ruby
class Foo < Angelo::Base
  include Angelo::Tilt::ERB
  include Angelo::Mustermann

  get '/:foo/things/:bar' do

    # `params` is merged with the Mustermann object#params hash, so
    # a "GET /some/things/are_good?foo=other&bar=are_bad" would have:
    #   params: {
    #     'foo' => 'some',
    #     'bar' => 'are_good'
    #   }

    @foo = params[:foo]
    @bar = params[:bar]
    erb :index
  end

end
```

NOTE: this always sets the Mustermann object's `type` to `:sinatra`

### Contributing

YES, HAVE SOME

* :fork_and_knife: Fork this repo, make changes, send PR!
* :shipit: if Good stuff?

### License

see LICENSE
