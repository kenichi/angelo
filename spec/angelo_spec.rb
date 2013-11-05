require_relative './spec_helper'

describe Angelo::Base do
  describe 'the basics' do

    let :obj do
      {'foo' => 'bar', 'bar' => 123.4567890123456, 'bat' => true}
    end

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
      string_vals = obj.keys.reduce({}){|h,k| h[k] = obj[k].to_s; h}
      last_response_should_be_json string_vals
    end

    it 'responds to post requests with json properly' do
      post '/json', obj.to_json, {'Content-Type' => Angelo::JSON_TYPE}
      last_response_should_be_json obj
    end

  end
end
