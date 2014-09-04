require_relative './spec_helper'

describe Angelo::Base do

  def obj
    {'foo' => 'bar', 'bar' => 123.4567890123456, 'bat' => true}
  end

  def obj_s
    obj.keys.reduce({}){|h,k| h[k] = obj[k].to_s; h}
  end

  describe 'the basics' do

    define_app do

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/' do
          m.to_s
        end
      end

      [:get, :post].each do |m|
        __send__ m, '/json' do
          content_type :json
          params
        end
      end

      get '/redirect' do
        redirect '/'
      end

      get '/wait' do
        sleep 3
        nil
      end

    end

    it 'responds to http requests properly' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/'
        last_response_must_be_html m.to_s
      end
    end

    it 'responds to get requests with json properly' do
      get '/json', obj
      last_response_must_be_json obj_s
    end

    it 'responds to post requests with json properly' do
      post '/json', obj.to_json, {'Content-Type' => Angelo::JSON_TYPE}
      last_response_must_be_json obj
    end

    it 'redirects' do
      get '/redirect'
      last_response.status.must_equal 301
      last_response.headers['Location'].must_equal '/'
    end

    it 'responds to requests concurrently' do
      wait_end = nil
      get_end = nil
      latch = CountDownLatch.new 2

      ActorPool.define_action :do_wait do
        get '/wait'
        wait_end = Time.now
        latch.count_down
      end

      ActorPool.define_action :do_get do
        sleep 1
        get '/'
        get_end = Time.now
        latch.count_down
      end

      ActorPool.unstop!
      $pool.async :do_wait
      $pool.async :do_get

      latch.wait
      get_end.must_be :<, wait_end

      ActorPool.stop!
      ActorPool.remove_action :do_wait
      ActorPool.remove_action :do_get
    end

    it 'does not crash when receiving unknown http request type' do
      r = HTTP.patch(url('/'))
      assert @server.alive?
      r.status.must_equal 404
    end

    it 'does not crash when receiving invalid uri' do
      s = TCPSocket.new Angelo::DEFAULT_ADDR, Angelo::DEFAULT_PORT
      s.write 'GET /?file=<SCRIPT>window.alert</SCRIPT>' + "\n\n"
      r = s.read
      s.close
      assert @server.alive?
      r.must_match /400 Bad Request/
    end

  end

  describe 'headers helper' do

    headers_count = 0

    define_app do

      put '/incr' do
        headers 'X-Http-Angelo-Server' => 'catbutt' if headers_count % 2 == 0
        headers_count += 1
        ''
      end

    end

    it 'sets headers for a response' do
      put '/incr'
      last_response.headers['X-Http-Angelo-Server'].must_equal 'catbutt'
    end

    it 'does not carry headers over responses' do
      headers_count = 0
      put '/incr'
      last_response.headers['X-Http-Angelo-Server'].must_equal 'catbutt'

      put '/incr'
      last_response.headers['X-Http-Angelo-Server'].must_be_nil
    end

  end

  describe 'content_type helper' do

    describe 'when in route block' do

      define_app do
        Angelo::HTTPABLE.each do |m|

          __send__ m, '/html' do
            content_type :html
            '<html><body>hi</body></html>'
          end

          __send__ m, '/bad_html_h' do
            content_type :html
            {hi: 'there'}
          end

          __send__ m, '/json' do
            content_type :json
            {hi: 'there'}
          end

          __send__ m, '/json_s' do
            content_type :json
            {woo: 'woo'}.to_json
          end

          __send__ m, '/bad_json_s' do
            content_type :json
            {hi: 'there'}.to_json.gsub /{/, 'so doge'
          end

          __send__ m, '/javascript' do
            content_type :js
            'var foo = "bar";'
          end

        end
      end

      it 'sets html content type for current route' do
        Angelo::HTTPABLE.each do |m|
          __send__ m, '/html'
          last_response_must_be_html '<html><body>hi</body></html>'
        end
      end

      it 'sets json content type for current route and to_jsons hashes' do
        Angelo::HTTPABLE.each do |m|
          __send__ m, '/json'
          last_response_must_be_json 'hi' => 'there'
        end
      end

      it 'does not to_json strings' do
        Angelo::HTTPABLE.each do |m|
          __send__ m, '/json_s'
          last_response_must_be_json 'woo' => 'woo'
        end
      end

      it '500s on html hashes' do
        Angelo::HTTPABLE.each do |m|
          __send__ m, '/bad_html_h'
          last_response.status.must_equal 500
        end
      end

      it '500s on bad json strings' do
        Angelo::HTTPABLE.each do |m|
          __send__ m, '/bad_json_s'
          last_response.status.must_equal 500
        end
      end

      it 'sets javascript content type for current route' do
        Angelo::HTTPABLE.each do |m|
          __send__ m, '/javascript'
          last_response.status.must_equal 200
          last_response.body.to_s.must_equal 'var foo = "bar";'
          last_response.headers['Content-Type'].split(';').must_include Angelo::JS_TYPE
        end
      end

    end

    describe 'when in class def' do

      describe 'html type' do

        define_app do
          content_type :html
          Angelo::HTTPABLE.each do |m|
            __send__ m, '/html' do
              '<html><body>hi</body></html>'
            end
          end
        end

        it 'sets default content type' do
          Angelo::HTTPABLE.each do |m|
            __send__ m, '/html'
            last_response_must_be_html '<html><body>hi</body></html>'
          end
        end

      end

      describe 'json type' do

        define_app do
          content_type :json
          Angelo::HTTPABLE.each do |m|
            __send__ m, '/json' do
              {hi: 'there'}
            end
          end
        end

        it 'sets default content type' do
          Angelo::HTTPABLE.each do |m|
            __send__ m, '/json'
            last_response_must_be_json 'hi' => 'there'
          end
        end
      end

    end

    describe 'when in both' do

      describe 'json in html' do

        define_app do
          content_type :html
          Angelo::HTTPABLE.each do |m|
            __send__ m, '/json' do
              content_type :json
              {hi: 'there'}
            end
          end
        end

        it 'sets html content type for current route when default is set json' do
          Angelo::HTTPABLE.each do |m|
            __send__ m, '/json'
            last_response_must_be_json 'hi' => 'there'
          end
        end

      end

      describe 'html in json' do

        define_app do
          content_type :json
          Angelo::HTTPABLE.each do |m|
            __send__ m, '/html' do
              content_type :html
              '<html><body>hi</body></html>'
            end
          end
        end

        it 'sets json content type for current route when default is set html' do
          Angelo::HTTPABLE.each do |m|
            __send__ m, '/html'
            last_response_must_be_html '<html><body>hi</body></html>'
          end
        end

      end

    end

  end

  describe 'params helper' do

    define_app do

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/json' do
          content_type :json
          params
        end
      end

    end

    it 'parses formencoded body when content-type is formencoded' do
      post '/json', obj, {'Content-Type' => Angelo::FORM_TYPE}
      last_response_must_be_json obj_s
    end

    it 'does not parse JSON body when content-type is formencoded' do
      post '/json', obj.to_json, {'Content-Type' => Angelo::FORM_TYPE}
      last_response.status.must_equal 400
    end

    it 'does not parse body when request content-type not set' do
      post '/json', obj, {'Content-Type' => ''}
      last_response_must_be_json({})
    end

    (Angelo::HTTPABLE - [:post, :put]).each do |m|
      it "returns a populated hash for #{m.to_s.upcase} requests" do
        send m, '/json?foo=bar'
        last_response_must_be_json('foo' => 'bar')
      end
    end

  end

  describe 'request_headers helper' do

    define_app do

      get '/rh' do
        content_type :json
        { values: [
            request_headers[params[:hk_1].to_sym],
            request_headers[params[:hk_2].to_sym],
            request_headers[params[:hk_3].to_sym]
          ]
        }
      end

    end

    it 'matches snakecased symbols against case insensitive header keys' do
      ps = {
        hk_1: 'foo_bar',
        hk_2: 'x_http_mozilla_ie_safari_puke',
        hk_3: 'authorization'
      }

      hs = {
        'Foo-BAR' => 'abcdef',
        'X-HTTP-Mozilla-IE-Safari-PuKe' => 'ghijkl',
        'Authorization' => 'Bearer oauth_token_hi'
      }

      get '/rh', ps, hs
      last_response_must_be_json 'values' => hs.values
    end

  end

end
