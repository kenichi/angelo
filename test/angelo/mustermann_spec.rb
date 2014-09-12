if RUBY_VERSION =~ /^2\./ and RUBY_PLATFORM != 'java'

  require_relative '../spec_helper'
  require 'angelo/mustermann'
  require 'angelo/tilt/erb'

  describe Angelo::Mustermann do

    describe 'pattern matching' do

      pattern = '/:foo/things/:bar'
      let(:mm_pattern){ ::Mustermann.new(pattern) }

      define_app do
        include Angelo::Mustermann
        content_type :json

        get pattern do
          params
        end

        [:post, :put].each do |m|
          __send__ m, pattern do
            params
          end
        end

      end

      it 'matches via mustermann routes objects' do
        path = '/some/things/are_good'
        get path
        last_response_must_be_json mm_pattern.params(path)
      end

      it 'overrides query string params' do
        path = '/some/things/are_good'
        get path, foo: 'other', bar: 'are_bad'
        last_response_must_be_json mm_pattern.params(path)
      end

      it 'overrides post body params' do
        path = '/some/things/are_good'
        headers = {Angelo::CONTENT_TYPE_HEADER_KEY => Angelo::JSON_TYPE}
        [:post, :put].each do |m|
          __send__ m, path, {foo: 'other', bar: 'are_bad'}.to_json, headers
          last_response_must_be_json mm_pattern.params(path)
        end
      end

      it '404s correctly for not found routes' do
        path = '/bad/monkey'
        get path
        last_response.status.must_equal 404
      end

    end

    describe 'tilt/erb integration' do

      define_app do
        include Angelo::Tilt::ERB
        include Angelo::Mustermann

        @root = TEST_APP_ROOT

        get '/:foo/things/:bar' do
          @title = params[:foo]
          @foo = 'bear'
          erb :index, locals: {bar: params[:bar]}
        end

      end

      it 'renders templates using mustermann params' do
        get '/aardvark/things/alpaca'
        expected = <<HTML
<!doctype html>
<html>
  <head>
    <title>aardvark</title>
  </head>
  <body>
    foo - bear
locals :bar - alpaca

  </body>
</html>
HTML
        last_response_must_be_html expected
      end

    end

  end

  describe 'filters' do

    describe 'params in route blocks' do

      define_app do
        include Angelo::Mustermann

        before '/before/:foo' do
          @foo = params[:foo]
        end

        content_type :json

        [:get, :post, :put].each do |m|
          __send__ m, '/before/:bar' do
            { bar: params[:bar], foo: params[:foo], foo_from_before: @foo }
          end
        end

      end

      it 'does not infect route block params with filter pattern params' do
        [:get, :post, :put].each do |m|
          __send__ m, '/before/hi'
          last_response_must_be_json 'bar' => 'hi', 'foo' => nil, 'foo_from_before' => 'hi'
        end
      end

    end

    describe 'wildcard' do

      define_app do
        include Angelo::Mustermann

        before do
          @foo = params[:foo]
        end

        before path: '/before*' do
          @bar = params[:bar] if @foo
          @bat = params[:bat] if @foo
        end

        [:get, :post, :put].each do |m|

          __send__ m, '/before' do
            content_type :json
            { foo: @foo, bar: @bar, bat: @bat }.select {|k,v| !v.nil?}
          end

          __send__ m, '/before_bar' do
            content_type :json
            { foo: @foo, bar: @bar, bat: @bat }.select {|k,v| !v.nil?}
          end

          __send__ m, '/before_bat' do
            content_type :json
            { foo: @foo, bar: @bar, bat: @bat }.select {|k,v| !v.nil?}
          end
        end

      end

      it 'runs wildcarded before filters' do

        get '/before_bar', obj
        last_response_must_be_json obj_s

        [:post, :put].each do |m|
          __send__ m, '/before_bar', obj.to_json, {Angelo::CONTENT_TYPE_HEADER_KEY => Angelo::JSON_TYPE}
          last_response_must_be_json obj
        end

        get '/before_bat', obj
        last_response_must_be_json obj_s

        [:post, :put].each do |m|
          __send__ m, '/before_bat', obj.to_json, {Angelo::CONTENT_TYPE_HEADER_KEY => Angelo::JSON_TYPE}
          last_response_must_be_json obj
        end

      end

    end

  end

end
