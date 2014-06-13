require_relative '../spec_helper'

describe Angelo::Base do

  describe :handle_error do

    after_ran = false
    before do
      after_ran = false
    end

    define_app do

      after do
        after_ran = true
      end

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/' do

          # this specificity (self.class::) is uneeded in actual practice
          # something about the anonymous class nature of self at this point
          # see Angelo::Minittest::Helpers#define_app
          #
          raise self.class::RequestError.new 'error message'
        end
      end

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/json' do
          content_type :json
          raise self.class::RequestError.new 'error message' # see above
        end
      end

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/msg_hash' do
          raise self.class::RequestError.new msg: 'error', foo: 'bar' # see above
        end
      end

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/msg_hash_json' do
          content_type :json
          raise self.class::RequestError.new msg: 'error', foo: 'bar' # see above
        end
      end

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/not_found' do
          raise self.class::RequestError.new 'not found', 404 # see above
        end
      end

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/enhance_your_calm' do
          raise self.class::RequestError.new 'enhance your calm, bro', 420 # see above
        end
      end

    end

    it 'handles raised errors correctly' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/'
        last_response.status.must_equal 400
        last_response.headers['Content-Type'].split(';').must_include Angelo::HTML_TYPE
        last_response.body.to_s.must_equal 'error message'
      end
    end

    it 'handles raised errors with json content type correctly' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/json'
        last_response.status.must_equal 400
        last_response.headers['Content-Type'].split(';').must_include Angelo::JSON_TYPE
        last_response.body.to_s.must_equal({error: 'error message'}.to_json)
      end
    end

    it 'handles raised errors with hash messages correctly' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/msg_hash'
        last_response.status.must_equal 400
        last_response.headers['Content-Type'].split(';').must_include Angelo::HTML_TYPE
        last_response.body.to_s.must_equal '{:msg=>"error", :foo=>"bar"}'
      end
    end

    it 'handles raised errors with hash messages with json content type correctly' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/msg_hash_json'
        last_response.status.must_equal 400
        last_response.headers['Content-Type'].split(';').must_include Angelo::JSON_TYPE
        last_response.body.to_s.must_equal({error: {msg: 'error', foo: 'bar'}}.to_json)
      end
    end

    it 'handles raising errors with other status codes correctly' do

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/not_found'
        last_response.status.must_equal 404
        last_response.headers['Content-Type'].split(';').must_include Angelo::HTML_TYPE
        last_response.body.to_s.must_equal 'not found'
      end

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/enhance_your_calm'
        last_response.status.must_equal 420
        last_response.headers['Content-Type'].split(';').must_include Angelo::HTML_TYPE
        last_response.body.to_s.must_equal 'enhance your calm, bro'
      end

    end

    it 'does not run after blocks when handling a raised error' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/'
        last_response.status.must_equal 400
        last_response.headers['Content-Type'].split(';').must_include Angelo::HTML_TYPE
        last_response.body.to_s.must_equal 'error message'
        refute after_ran, 'after block should not have ran'
      end
    end

  end

  describe :halt do

    after_ran = false
    before do
      after_ran = false
    end

    define_app do

      after do
        after_ran = true
      end

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/halt' do
          halt
          raise RequestError.new "shouldn't get here"
        end
      end

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/teapot' do
          halt 418, "i'm a teapot"
          raise RequestError.new "shouldn't get here"
        end
      end

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/calm_json' do
          content_type :json
          halt 420, {calm: 'enhance'}
          raise RequestError.new "shouldn't get here"
        end
      end

    end

    it 'halts properly' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/halt'
        last_response.status.must_equal 400
        last_response.headers['Content-Type'].split(';').must_include Angelo::HTML_TYPE
        last_response.body.to_s.must_equal ''
      end
    end

    it 'halts with different status code properly' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/teapot'
        last_response.status.must_equal 418
        last_response.headers['Content-Type'].split(';').must_include Angelo::HTML_TYPE
        last_response.body.to_s.must_equal "i'm a teapot"
      end
    end

    it 'halts with json content type correctly' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/calm_json'
        last_response.status.must_equal 420
        last_response.headers['Content-Type'].split(';').must_include Angelo::JSON_TYPE
        last_response.body.to_s.must_equal({error: {calm: 'enhance'}}.to_json)
      end
    end

    it 'runs after blocks when halting' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/halt'
        last_response.status.must_equal 400
        last_response.headers['Content-Type'].split(';').must_include Angelo::HTML_TYPE
        last_response.body.to_s.must_equal ''
        assert after_ran, 'after block should have ran'
      end
    end

  end

end
