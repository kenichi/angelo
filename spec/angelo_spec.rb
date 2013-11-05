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
      string_vals = obj.keys.reduce({}){|h,k| h[k] = obj[k].to_s; h}
      last_response_should_be_json string_vals
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

end
