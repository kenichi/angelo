changelog
=========

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
