if RUBY_VERSION =~ /^2\./

  require_relative '../spec_helper'
  require 'angelo/mustermann'

  TILT_MM_TEST_ROOT = File.expand_path '..', __FILE__

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
        last_response_should_be_json mm_pattern.params(path)
      end

      it 'overrides query string params' do
        path = '/some/things/are_good'
        get path, foo: 'other', bar: 'are_bad'
        last_response_should_be_json mm_pattern.params(path)
      end

      it 'overrides post body params' do
        path = '/some/things/are_good'
        headers = {Angelo::CONTENT_TYPE_HEADER_KEY => Angelo::JSON_TYPE}
        [:post, :put].each do |m|
          __send__ m, path, {foo: 'other', bar: 'are_bad'}.to_json, headers
          last_response_should_be_json mm_pattern.params(path)
        end
      end

    end

    describe 'tilt/erb integration' do

      define_app do
        include Angelo::Tilt::ERB
        include Angelo::Mustermann

        @root = TILT_MM_TEST_ROOT

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
        last_response_should_be_html expected
      end

    end

  end

end
