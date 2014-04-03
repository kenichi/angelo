Angelo
======

[![Build Status](https://travis-ci.org/kenichi/angelo.png?branch=master)](https://travis-ci.org/kenichi/angelo)

A [Sinatra](https://github.com/sinatra/sinatra)-esque DSL for [Reel](https://github.com/celluloid/reel).

### Notes/Features

* "easy" websocket support via `socket '/path' do |s|` route handler
* "easy" websocket stashing via `websockets` helper
* "easy" event handling via `async` helpers
* no rack
* optional tilt/erb support
* optional mustermann support

Lots of work left to do!

### Quick example

```ruby
require 'angelo'
require 'angelo/mustermann'

class Foo < Angelo::Base
  include Angelo::Mustermann

  TEST = {foo: "bar", baz: 123, bat: false}.to_json

  HEART = '<3'
  @@hearting = false

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
    ws.on_message do |msg|
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

  socket '/hearts' do |ws|

    # this is a call to Base#async, actually calling 
    # the reactor to start the task
    # 
    async :hearts unless @@hearting

    websockets[:hearts] << ws
  end

  # this is a call to Base.task, defining the task
  # to perform on the reactor
  #
  task :hearts do
    @@hearting = true
    every(10){ websockets[:hearts].each {|ws| ws.write HEART } }
  end

  post '/in/:sec/sec/:msg' do

    # this is a call to Base#future, telling the reactor
    # do this thing and we'' want the value eventually
    #
    f = future :in_sec params[:sec], params[:msg]
    f.value
  end

  task :in_sec do |sec, msg|
    sleep sec.to_i
    msg
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
