require_relative '../spec_helper'

describe Angelo::Base do

  describe :handle_error do

    define_app do

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

    end

    it 'handles raised errors correctly' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/'
        last_response.status.must_equal 400
        last_response.headers['Content-Type'].split(';').must_include Angelo::HTML_TYPE
        last_response.body.must_equal 'error message'
      end
    end

    it 'handles raised errors with json content type correctly' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/json'
        last_response.status.must_equal 400
        last_response.headers['Content-Type'].split(';').must_include Angelo::JSON_TYPE
        last_response.body.must_equal({error: 'error message'}.to_json)
      end
    end

    it 'handles raised errors with hash messages correctly' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/msg_hash'
        last_response.status.must_equal 400
        last_response.headers['Content-Type'].split(';').must_include Angelo::HTML_TYPE
        last_response.body.must_equal '{:msg=>"error", :foo=>"bar"}'
      end
    end

    it 'handles raised errors with hash messages with json content type correctly' do
      Angelo::HTTPABLE.each do |m|
        __send__ m, '/msg_hash_json'
        last_response.status.must_equal 400
        last_response.headers['Content-Type'].split(';').must_include Angelo::JSON_TYPE
        last_response.body.must_equal({error: {msg: 'error', foo: 'bar'}}.to_json)
      end
    end

  end

end
