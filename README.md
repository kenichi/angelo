Angelo
======

[![Build Status](https://travis-ci.org/kenichi/angelo.png?branch=master)](https://travis-ci.org/kenichi/angelo)

A [Sinatra](https://github.com/sinatra/sinatra)-like DSL for [Reel](https://github.com/celluloid/reel).

### tl;dr

* websocket support via `websocket('/path'){|s| ... }` route builder
* SSE support via `eventsource('/path'){|s| ... }` route builder
* contextual websocket/sse stashing via `websockets` and `sses` helpers
* `task` handling via `async` and `future` helpers
* no rack
* erb, haml, and markdown support
* mustermann support

### What is Angelo?

Just like Sinatra, Angelo gives you an expressive DSL for creating web applications. There are some
notable differences, but the basics remain the same: you can either create a "classic" application
by requiring 'angelo/main' and using the DSL at the top level of your script, or a "modular"
application by requiring 'angelo', subclassing `Angelo::Base`, and calling `.run!` on that class for the
service to start.
In addition, and perhaps more importantly, **Angelo is built on Reel, which is built on
Celluloid::IO and gives you a reactor with evented IO in Ruby!**

Things will feel very familiar to anyone experienced with Sinatra. You can define
route handlers denoted by HTTP verb and path with parameters set from path matching (using
[Mustermann](#mustermann)), the query string, and post body.
A route block may return:

* The body of the response in full as a `String`.
* A `Hash` (or anything that `respond_to? :to_json`) if the content type is set to `:json`.
* Any object that responds to `#each(&block)` if the transfer encoding is set to `:chunked`.
There is also a `chunked_response` helper that will take a block, set the transfer encoding, and return
an appropriate object.

Angelo also features `before` and `after` filter blocks, just like Sinatra. Filters are ordered as defined,
and called in that order. When defined without a path, they run for all matched requests. With a path,
the path is interpreted as a Mustermann pattern and params are merged. `before` filters can set instance
variables which can be used in the route block and the `after` filter.
For more info on the difference in how after blocks are handled, see the Errors section below for more info.

### Websockets!

One of the main motivations for Angelo was the ability to define websocket handlers with ease. Through
the addition of a `websocket` route builder and a `websockets` helper, Angelo attempts to make it easy
for you to build real-time web applications.

##### Route Builder

The `websocket` route builder accepts a path and a block, and passes the actual websocket to the block
as the only argument. This socket is an instance of Reel's
[WebSocket](https://github.com/celluloid/reel/blob/master/lib/reel/websocket.rb) class, and, as such,
responds to methods like `on_message` and `on_close`. A service-wide `on_pong` handler may be defined
to customize the behavior when a pong frame comes back from a connected websocket client.

##### `websockets` helper

Angelo includes a "stash" helper for connected websockets. One can `<<` a websocket into `websockets`
from inside a websocket handler block. These can "later" be iterated over so one can do things like
emit a message on every connected websocket when the service receives a POST request.

The `websockets` helper also includes a context ability, so you can stash connected websocket clients
into different "sections". Also, by default, the helper will `reject!` any closed sockets before
returning; you may optionally pass `false` to the helper to skip this step.

##### Example!

Here is an example of the `websocket` route builder, the `websockets` helper, and the context feature:

```ruby
require 'angelo'

class Foo < Angelo::Base

  websocket '/' do |ws|
    websockets << ws
  end

  websocket '/bar' do |ws|
    websockets[:bar] << ws
  end

  post '/' do
    websockets.each {|ws| ws.write params[:foo]}
  end

  post '/bar' do
    websockets[:bar].each {|ws| ws.write params[:bar]}
  end

end

Foo.run!
```

In this case, any clients that connect to a websocket at the path '/' will be stashed in the
default websockets array; clients that connect to '/bar' will be stashed in the `:bar` section.

Each "section" is accessed with a familiar, `Hash`-like syntax, and can be iterated over with
a `.each` block.

When a `POST /` with a 'foo' param is received, any value is messaged out to all '/' connected
websockets. When a `POST /bar` with a 'bar' param is received, any value is messaged out to all
websockets connected to '/bar'.

### SSE - Server-Sent Events

The `eventsource` route builder also accepts a path and a block, and passes the socket to the block,
just like the `websocket` builder. This socket is actually the raw `Celluloid::IO::TCPSocket` and is
"detached" from the regular handling. There are no "on-*" methods; the `write` method should suffice.
To make it easier to deal with creation of the properly formatted Strings to send, Angelo provides
a couple helpers.

##### `sse_event` helper

To create an "event" that a javascript EventListener on the client can respond to:

```ruby
eventsource '/sse' do |s|
  event = sse_event :foo, some_key: 'blah', other_key: 'boo'
  s.write event
  s.close
end
```

In this case, the EventListener would have to be configured to listen for the `foo` event:

```javascript
var sse = new EventSource('/sse');
sse.addEventListener('foo', function(e){ console.log("got foo event!\n" + JSON.parse(e.data)); });
```

The `sse_event` helper accepts a normal `String` for the data, but will automatically convert a `Hash`
argument to a JSON object.

NOTE: there is a shortcut helper on the actual SSE object itself:

```ruby
eventsource '/sse' do |sse|
  sse.event :foo, some_key: 'blah', other_key: 'boo'
  sse.event :close
end
```

##### `sse_message` helper

The `sse_message` helper behaves exactly the same as `sse_event`, but does not take an event name:

```ruby
eventsource '/sse' do |s|
  msg = sse_message some_key: 'blah', other_key: 'boo'
  s.write msg
  s.close
end
```

The client javascript would need to be altered to use the `EventSource.onmessage` property as well:

```javascript
var sse = new EventSource('/sse');
sse.onmessage = function(e){ console.log("got message!\n" + JSON.parse(e.data)); };
```

NOTE: there is a shortcut helper on the actual SSE object itself:

```ruby
eventsource '/sse' do |sse|
  sse.message some_key: 'blah', other_key: 'boo'
  sse.event :close
end
```

##### `sses` helper

Angelo also includes a "stash" helper for SSE connections. One can `<<` a socket into `sses` from
inside an `eventsource` handler block. These can "later" be iterated over so one can do things
like emit a message on every SSE connection when the service receives a POST request.

The `sses` helper includes the same context ability as the `websockets` helper. Also, by default,
the helper will `reject!` any closed sockets before returning, just like `websockets`. You may
optionally pass `false` to the helper to skip this step. In addition, the `sses` stash includes
methods for easily sending events or messages to all stashed connections. **Note that the
`Stash::SSE#event` method only works on non-default contexts and uses the context name as the event
name.**

```ruby
eventsource '/sse' do |s|
  sses[:foo] << s
end

post '/sse_message' do
  sses[:foo].message params[:data]
end

post '/sse_event' do
  sses[:foo].event params[:data]
end
```

##### `eventsource` instance helper

Additionally, you can also start SSE handling *conditionally* from inside a GET block:

```ruby
get '/sse_maybe' do
  if params[:sse]
    eventsource do |c|
      sses << c
      c.write sse_message 'wooo fancy SSE for you!'
    end
  else
    'boring regular old get response'
  end
end

post '/sse_event' do
  sses.each {|sse| sse.write sse_event(:foo, 'fancy sse event!')}
end
```

Handling this on the client may require conditionals for [browsers](http://caniuse.com/eventsource) that
do not support EventSource yet, since this will respond with a non-"text/event-stream" Content-Type if
'sse' is not present in the params.

##### `EventSource#on_close` helper

When inside an eventsource block, you may want to do something specific when a client closes the
connection. For this case, there are `on_close` and `on_close=` methods on the object passed to the block
that will get called if the client closes the socket. The assignment method takes a proc object and the
other one takes a block:

```ruby
get '/' do
  eventsource do |es|

    # assignment!
    es.on_close = ->{sses(false).remove_socket es}

    sses << es
  end
end

eventsource '/sse' do |es|

  # just passing a block here
  es.on_close {sses(false).remove_socket es}

  sses << es
end
```

Note the use of the optional parameter of the stashes here; by default, stash accessors (`websockets` and
`sses`) will `reject!` any closed sockets before letting you in. If you pass `false` to the stash
accessors, they will skip the `reject!` step.

### Tasks + Async / Future

Angelo is built on Reel and Celluloid::IO, giving your web application the ability to define
"tasks" and call them from route handler blocks in an `async` or `future` style.

##### `task` builder

You can define a task on the reactor using the `task` class method and giving it a symbol and a
block. The block can take arguments that you can pass later, with `async` or `future`.

```ruby
# defining a task on the reactor called `:in_sec` which will sleep for
# the given number of seconds, then return the given message.
#
task :in_sec do |sec, msg|
  sleep sec.to_i
  msg
end
```

##### `async` helper

This helper is directly analogous to the Celluoid method of the same name. Once tasks are defined,
you can call them with this helper method, passing the symbol of the task name and any arguments.
The task will run on the reactor, asynchronously, and return immediately.

```ruby
get '/' do
  # run the task defined above asynchronously, return immediately
  #
  async :in_sec, params[:sec], params[:msg]

  # NOTE: params[:msg] is discarded, the return value of tasks called with `async` is nil.

  # return this response body while the task is still running
  # assuming params[:sec] is > 0
  #
  'hi'
end
```

##### `future` helper

Just like `async`, this comes from Celluloid as well. It behaves exactly like `async`, with the
notable exception of returning a "future" object that you can call `#value` on later to retrieve
the return value of the task. Calling `#value` will "block" until the task is finished, while the
reactor continues to process requests.

```ruby
get '/' do
  # run the task defined above asynchronously, return immediately
  #
  f = future :in_sec, params[:sec], params[:msg]

  # now, block until the task is finished and return the task's value
  # as a response body
  #
  f.value
end
```

### Errors and Halting

Angelo gives you two ordained methods of stopping route processing:

* raise an instance of `RequestError`
* `halt` with a status code and message

The main difference is that `halt` will still run `after` blocks, and raising `RequestError`
will bypass `after` blocks.

Any other exceptions or errors raised by your route handler will be handled with a 500 status
code and the message will be the body of the response.

#### RequestError

Raising an instance of `Angelo::RequestError` causes a 400 status code response, and the message
in the instance is the body of the the response. If the route or class was set to respond with
JSON, the body is converted to a JSON object with one key, `error`, that has the value of the message.
If the message is a `Hash`, the hash is converted to a JSON object, or to a string for other content
types.

If you want to return a different status code, you can pass it as a second argument to
`RequestError.new`. See example below.

#### Halting

You can `halt` from within any route handler, optionally passing status code and a body. The
body is handled the same way as raising `RequestError`.

##### Example

```ruby
get '/' do
  raise RequestError.new '"foo" is a required parameter' unless params[:foo]
  params[:foo]
end

get '/json' do
  content_type :json
  raise RequestError.new foo: "required!"
  {foo: params[:foo]}
end

get '/not_found' do
  raise RequestError.new 'not found', 404
end

get '/halt' do
  halt 200, "everything's fine"
  raise RequestError.new "won't get here"
end
```

```
$ curl -i http://127.0.0.1:4567/
HTTP/1.1 400 Bad Request
Content-Type: text/html
Connection: Keep-Alive
Content-Length: 29

"foo" is a required parameter

$ curl -i http://127.0.0.1:4567/?foo=bar
HTTP/1.1 200 OK
Content-Type: text/html
Connection: Keep-Alive
Content-Length: 3

bar

$ curl -i http://127.0.0.1:4567/json
HTTP/1.1 400 Bad Request
Content-Type: application/json
Connection: Keep-Alive
Content-Length: 29

{"error":{"foo":"required!"}}

$ curl -i http://127.0.0.1:4567/not_found
HTTP/1.1 404 Not Found
Content-Type: text/html
Connection: Keep-Alive
Content-Length: 9

not found

$ curl -i http://127.0.0.1:4567/halt
HTTP/1.1 200 OK
Content-Type: text/html
Connection: Keep-Alive
Content-Length: 18

everything's fine
```

### [Tilt](https://github.com/rtomayko/tilt) / ERB

```ruby
class Foo < Angelo::Base

  views_dir 'some/other/path' # defaults to './views'

  get '/' do
    erb :index
  end

end
```

The Angleo::Tilt::ERB module and the `erb` method do some extra work for you:

* templates are pre-compiled, sorted by type.
* template type is determined by word between name and .erb (ex: `index.html.erb`
  is `:index` name and `:html` type)
* the template chosen to render is determined based on:
    * `:type` option passed to `erb` helper
    * `Accept` request header value
    * `Content-Type` response header value
    * default to `:html`

See [views](https://github.com/kenichi/angelo/tree/master/test/test_app_root/views) for examples.

### [Mustermann](https://github.com/rkh/mustermann)

```ruby
class Foo < Angelo::Base

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

  before '/:fu/things/*' do

    # `params` is merged with the Mustermann object#params hash, as
    # parsed with the current request path against this before block's
    # pattern. in the route handler, `params[:fu]` is no longer available.

    @fu = params[:fu]
  end

end
```

### Classic vs. modular apps

Like Sinatra, Angelo apps can be written in either "classic" style or
so-called "modular" style.  Which style you use is more of a personal
preference than anything else.

A classic-style app requires "angelo/main" and defines the app
directly at the top level using the DSL.  In addition, classic apps:

* Can use a `helpers` block to define methods that can be called from
filters and route handlers. The `helpers` method can also include methods
from one or more modules passed as arguments instead of or in addition
to taking a block.
* Parse optional command-line options "-o addr" and "-p port" to set
the bind address and listen port, respectively.
* Are run automatically.

*Note: unlike Sinatra, define a classic app by requiring "angelo/main"
and a modular app by requiring "angelo".  Sinatra uses "sinatra" and
"sinatra/base" to do the same things.*

Here's a classic app:

```ruby
require 'angelo/main'

helpers do
  def say_hello
    "Hello"
  end
end

get "/hello" do
  "#{say_hello} to you, too."
end
```

And the same app in modular style:

```ruby
require 'angelo'

class HelloApp < Angelo::Base
  def say_hello
    "Hello"
  end

  get "/hello" do
    "#{say_hello} to you, too."
  end
end

HelloApp.run!
```

### JSON HTTP API

If you post JSON data with a JSON Content-Type, angelo will:

* merge objects into the `params` SymHash
* parse arrays and make them available via `request_body`

N.B. `request_body` is functionally equivalent to `request.body.to_s` otherwise.

If your `content_type` is set to `:json`, angelo will convert:

* anything returned from a route block that `respond_to? :to_json`
* `RequestError` message data
* `halt` data

### Documentation

**I'm bad at documentation and I feel bad.**

Others have helped, and there is a YaRD plugin for Angelo [here](https://github.com/artcom/yard-angelo)
if you would like to document your apps built with Angelo. (thanks: @katjaeinsfeld, @artcom)

### WORK LEFT TO DO

Lots of work left to do!

### Full-ish example

```ruby
require 'angelo'

class Foo < Angelo::Base

  # just some constants to use in routes later...
  #
  TEST = {foo: "bar", baz: 123, bat: false}.to_json
  HEART = '<3'

  # a flag to know if the :heart task is running
  #
  @@hearting = false

  # you can define instance methods, just like Sinatra!
  #
  def pong; 'pong'; end
  def foo; params[:foo]; end

  # standard HTTP GET handler
  #
  get '/ping' do
    pong
  end

  # standard HTTP POST handler
  #
  post '/foo' do
    foo
  end

  post '/bar' do
    params.to_json
  end

  # emit the TEST JSON value on all :emit_test websockets
  # return the params posted as JSON
  #
  post '/emit' do
    websockets[:emit_test].each {|ws| ws.write TEST}
    params.to_json
  end

  # handle websocket requests at '/ws'
  # stash them in the :emit_test context
  # write 6 messages to the websocket whenever a message is received
  #
  websocket '/ws' do |ws|
    websockets[:emit_test] << ws
    ws.on_message do |msg|
      5.times { ws.write TEST }
      ws.write foo.to_json
    end
  end

  # emit the TEST JSON value on all :other websockets
  #
  post '/other' do
    websockets[:other].each {|ws| ws.write TEST}
    ''
  end

  # stash '/other/ws' connected websockets in the :other context
  #
  websocket '/other/ws' do |ws|
    websockets[:other] << ws
  end

  websocket '/hearts' do |ws|

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
    # do this thing and we'll want the value eventually
    #
    f = future :in_sec, params[:sec], params[:msg]
    f.value
  end

  # define a task on the reactor that sleeps for the given number of
  # seconds and returns the given message
  #
  task :in_sec do |sec, msg|
    sleep sec.to_i
    msg
  end

  # return a chunked response of JSON for 5 seconds
  #
  get '/chunky_json' do
    content_type :json

    # this helper requires a block that takes one arg, the response
    # proc to call with each chunk (i.e. the block that is passed to
    # `#each`)
    #
    chunked_response do |response|
      5.times do
        response.call time: Time.now.to_i
        sleep 1
      end
    end
  end

end

Foo.run!
```

### Contributing

Anyone is welcome to contribute. Conduct is guided by the [Contributor Covenant](http://contributor-covenant.org).
See `code_of_conduct.md`.

To contribute to Angelo, please:

* fork the repository to your GitHub account
* create a branch for the feature or fix
* commit your changes to that branch, please include tests if applicable
* submit a Pull Request back to the main repository's `master` branch

After review and acceptance, your changes will be merged and noted in `CHANGLOG.md`.

### Testing

Unit tests are done with Minitest. Run them with :

```
bundle install
rake test
```

### License

[Apache 2.0](LICENSE)

### Name

Why the name "Angelo"? Since the project mimics Sinatra's DSL, I thought it best to keep a reference to
The Chairman in the name. It turns out that Frank Sinatra won an Academy Award for his role 'Angelo
Maggio' in 'From Here to Eternity'. I appropriated the name since this is like Sinatra on Reel (film).
