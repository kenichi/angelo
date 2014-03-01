require_relative './spec_helper'

describe Angelo::Base do

  let :obj do
    {'foo' => 'bar', 'bar' => 123.4567890123456, 'bat' => true}
  end
  let(:obj_s) {
    obj.keys.reduce({}){|h,k| h[k] = obj[k].to_s; h}
  }

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

    end

    it 'responds to http requests properly' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/'
        last_response_should_be_html m.to_s
      end
    end

    it 'responds to get requests with json properly' do
      get '/json', obj
      last_response_should_be_json obj_s
    end

    it 'responds to post requests with json properly' do
      post '/json', obj.to_json, {'Content-Type' => Angelo::JSON_TYPE}
      last_response_should_be_json obj
    end

  end

  describe 'before filter' do

    define_app do

      before do
        @set_by_before = params
      end

      [:get, :post, :put].each do |m|
        __send__ m, '/before' do
          content_type :json
          @set_by_before
        end
      end

    end

    it 'runs before filters before routes' do

      get '/before', obj
      last_response_should_be_json obj_s

      [:post, :put].each do |m|
        __send__ m, '/before', obj.to_json, {Angelo::CONTENT_TYPE_HEADER_KEY => Angelo::JSON_TYPE}
        last_response_should_be_json obj
      end

    end

  end

  describe 'after filter' do

    invoked = 0

    define_app do

      before do
        invoked += 2
      end

      after do
        invoked *= 2
      end

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/after' do
          invoked.to_s
        end
      end

    end

    it 'runs after filters after routes' do
      a = %w[2 6 14 30]
      b = [4, 12, 28, 60]
      Angelo::HTTPABLE.each_with_index do |m,i|
        __send__ m, '/after', obj
        last_response_should_be_html a[i]
        invoked.should eq b[i]
      end
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

        end
      end

      it 'sets html content type for current route' do
        Angelo::HTTPABLE.each do |m|
          __send__ m, '/html'
          last_response_should_be_html '<html><body>hi</body></html>'
        end
      end

      it 'sets json content type for current route and to_jsons hashes' do
        Angelo::HTTPABLE.each do |m|
          __send__ m, '/json'
          last_response_should_be_json 'hi' => 'there'
        end
      end

      it 'does not to_json strings' do
        Angelo::HTTPABLE.each do |m|
          __send__ m, '/json_s'
          last_response_should_be_json 'woo' => 'woo'
        end
      end

      it '500s on html hashes' do
        Angelo::HTTPABLE.each do |m|
          __send__ m, '/bad_html_h'
          last_response.status.should eq 500
        end
      end

      it '500s on bad json strings' do
        Angelo::HTTPABLE.each do |m|
          __send__ m, '/bad_json_s'
          last_response.status.should eq 500
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
            last_response_should_be_html '<html><body>hi</body></html>'
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
            last_response_should_be_json 'hi' => 'there'
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
            last_response_should_be_json 'hi' => 'there'
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
            last_response_should_be_html '<html><body>hi</body></html>'
          end
        end

      end

    end

  end

  describe 'params helper' do

    define_app do

      [:get, :post].each do |m|
        __send__ m, '/json' do
          content_type :json
          params
        end
      end

    end

    it 'parses formencoded body when content-type is formencoded' do
      post '/json', obj, {'Content-Type' => Angelo::FORM_TYPE}
      last_response_should_be_json obj_s
    end

    it 'does not parse JSON body when content-type is formencoded' do
      post '/json', obj.to_json, {'Content-Type' => Angelo::FORM_TYPE}
      last_response.status.should eq 400
    end

    it 'does not parse body when request content-type not set' do
      post '/json', obj, {'Content-Type' => ''}
      last_response_should_be_json({})
    end

  end

  describe 'websockets helper' do
  end

end
