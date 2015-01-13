changelog
=========

### 0.3.3

thanks: @mighe, @tarcieri, @jc00ke

* update tests for 2.2.0 URI.parse (https://bugs.ruby-lang.org/issues/10669)
* `public_dir` accessor forwarded from base now
* `redirect` returns nil
* travis tests against rbx (#23)

### 0.3.2 27 nov 2014 ¡gracias!

thanks: @mighe, @artworx

* send_file now accepts both full paths and paths relative to app file's dir (#20)
* erb templates now sorted by type, finer control of response template type (#19)

### 0.3.1 10 nov 2014 yep, same day - jeez

* refactor views dir and public dir setting into top level DSLish methods
    * set views path with `views_dir 'vues'`
    * set public path with `public_dir 'publick'`

### 0.3.0 10 nov 2014

thanks: @mighe

* refactor bind address, port, log level and error reporting setting into top level DSLish methods
    * set bind address with `addr '0.0.0.0'`
    * set bind port with `port 4567`
    * set log level with `log_level ::Logger::DEBUG`
    * set error reporting with `report_errors!`
    * bind address and port can still be specified on `.run` or `.run!` calls
* remove command line option parsing completely

### 0.2.4 4 nov 2014 totally voted

thanks: @mighe

* fix for responding more than once to websocket and sse requests (#17)
* clean up gemfile and gemspec

### 0.2.3 28 oct 2014

thanks: @mighe, @chewi

* add flag (default: false) to `Base.run` to trap INT and sleep or not
* add `Base.run!` which calls `.run` with flag set true
* fix for form params keys with no values

### 0.2.2 22 oct 2014

thanks: @chewi

* add on_close setter to EventSource
* fix peeraddr forward on EventSource

### 0.2.1 7 oct 2014

thanks: @chewi

* fix stash socket iteration error handling (#11)

### 0.2.0 23 sep 2014

* chunked responses with `transfer_encoding :chunked` and `return_obj.each`
* chunked responses with `chunked_response(){|r| ... }`
* `event` and `message` helpers on sse objects

### 0.1.24 19 sep 2014

thanks: @chewi

* handle RequestError in before blocks for eventsource properly (#9)

### 0.1.23 18 sep 2014

thanks: @chewi, @samjohnduke

* multiple before/after filters with mustermann support (#3)
* accept extra headers in eventsource route builder (#6)
* handle errors in before blocks for eventsource-built routes (#6)
* let DELETE and OPTIONS routes see query params (#8)

### 0.1.22 9 sep 2014

* handle bad/malformed requests better

### 0.1.21 10 aug 2014

* add forward for SSE stash from Server for tasks

### 0.1.19 10 aug 2014

* fix crash on unsupported HTTP request types
* more info in debug messages from sockets/stashes

### 0.1.18 9 aug 2014

* handle more errors during ws read task

### 0.1.17 9 aug 2014

* add Base#send_data
* add ability to pass options to Mustermann instances

### 0.1.16 8 aug 2014

* recursively symhash JSON POST bodies
* add options route builder

### 0.1.15 24 jul 2014

* WebsocketResponder -> Responder::Websocket
* add Responder::Eventsource
* split Stash into module with Websocket and SSE classes
* add SSE eventsource route builder and helper
* add #event and #message to Stash::SSE
* add .sse_event and .sse_message to Base

### 0.1.14 3 jul 2014

* add send_file with disposition support
* remove disposition header from static file serving

### 0.1.13 19 jun 2014

* add log level settings
* make response logging default to :info level
* catch SystemCallError, IOError in Stash#each\* methods

### 0.1.12 17 jun 2014

* before and after blocks now wrap websocket routes
* add :js content_type

### 0.1.11 13 jun 2014

* add halt method and handling

### 0.1.10 12 jun 2014

* add RequestError and handling

### 0.1.9 5 jun 2014

* make Mustermann::RouteMap not descend from Hash
* replace WebsocketsArray < Array with Stash
* fix WebsocketRepsonder.close_socket

### 0.1.8 6 may 2014

* leave RSpec for Minitest
* fix for Reel::Connection::StateError -> Reel::StateError
* rename "socket" route definition to "websocket"

### 0.1.7 17 apr 2014

* reel 0.5.0 support (Reel::Server -> Reel::Server::HTTP)

### 0.1.6 2 apr 2014

* better testing of Responder#headers
* better handling of Responder#redirect
* add Base#request_headers helper
* rename Base.async -> Base.task, add Base#future

### 0.1.5 31 mar 2014

* add WebsocketsArray#all
* fix websockets pinging to ping all connected sockets
* add Responder#redirect

### 0.1.4 26 mar 2014

* add Base.async, Base.on_pong, and Base#async
* fix websockets context handling, removal
* add ping task to reactor

### 0.1.3 24 mar 2014

* better testing of websockets
* slightly better handling of socket errors
* static file content type fix

### 0.1.2 5 mar 2014 burnout, denial

* basic static file support (i.e. /public files)
* basic ETag/If-None-Match support

### 0.1.1 3 mar 2014

* fix for params with no Content-Type header

### 0.1.0 24 feb 2014

* fix for socket paths with mustermann
* sorta common log-ish-ness

### 0.0.9 20 feb 2014

* memoize params
* slight changes for mustermann
* add '-o addr' bind to address cmd line option
* add '-p port' bind to port cmd line option

### 0.0.8 5 nov 2013 gunpowder treason

* add mustermann support

### 0.0.7 5 nov 2013

* fix gemspec
* add codename
* travis

### 0.0.6 5 nov 2013

* rspec and tests!
* lots of fixing broken that testing found
* contextualized websockets helper

### 0.0.5 31 oct 2013 SPOOOOKEEEE

* add Base.content_type
* Responder#content_type= -> Responder#content_type
* properly delegated to Responder

### 0.0.4 30 oct 2013

* inadvertent yank of 0.0.3

### 0.0.3 30 oct 2013

* added tilt/erb
* added before/after
* added content_type/headers
* better websockets error handling

### 0.0.2 29 oct 2013

* added websockets helper

### 0.0.1 28 oct 2013

* initial release
* get/post/put/delete/options support
* socket support
