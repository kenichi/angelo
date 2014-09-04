require_relative '../spec_helper.rb'

describe Angelo::Base do

  def obj
    {'foo' => 'bar', 'bar' => 123.4567890123456, 'bat' => true}
  end

  def obj_s
    obj.keys.reduce({}){|h,k| h[k] = obj[k].to_s; h}
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
      last_response_must_be_json obj_s

      [:post, :put].each do |m|
        __send__ m, '/before', obj.to_json, {Angelo::CONTENT_TYPE_HEADER_KEY => Angelo::JSON_TYPE}
        last_response_must_be_json obj
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
      a = %w[2 6 14 30 62]
      b = [4, 12, 28, 60, 124]

      Angelo::HTTPABLE.each_with_index do |m,i|
        __send__ m, '/after', obj
        last_response_must_be_html a[i]
        invoked.must_equal b[i]
      end
    end

  end

end
