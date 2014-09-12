require_relative '../spec_helper.rb'

describe Angelo::Base do

  describe 'before filter' do

    describe 'single default' do

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

    describe 'multiple default' do

      define_app do

        before do
          @foo = params[:foo]
        end

        before do
          @bar = params[:bar] if @foo
        end

        before do
          @bat = params[:bat] if @bar
        end

        [:get, :post, :put].each do |m|
          __send__ m, '/before' do
            content_type :json
            { foo: @foo, bar: @bar, bat: @bat }
          end
        end

      end

      it 'runs before filters in order' do

        get '/before', obj
        last_response_must_be_json obj_s

        [:post, :put].each do |m|
          __send__ m, '/before', obj.to_json, {Angelo::CONTENT_TYPE_HEADER_KEY => Angelo::JSON_TYPE}
          last_response_must_be_json obj
        end

      end

    end

    describe 'pathed' do

      define_app do

        before do
          @foo = params[:foo]
        end

        before '/before_bar' do
          @bar = params[:bar] if @foo
        end

        before path: '/before_bat' do
          @bat = params[:bat] if @foo
        end

        [:get, :post, :put].each do |m|

          __send__ m, '/before' do
            content_type :json
            { foo: @foo, bar: @bar, bat: @bat }.select! {|k,v| !v.nil?}
          end

          __send__ m, '/before_bar' do
            content_type :json
            { foo: @foo, bar: @bar, bat: @bat }.select! {|k,v| !v.nil?}
          end

          __send__ m, '/before_bat' do
            content_type :json
            { foo: @foo, bar: @bar, bat: @bat }.select! {|k,v| !v.nil?}
          end
        end

      end

      it 'runs default before filter for all paths' do

        get '/before', obj
        last_response_must_be_json obj_s.select {|k,v| k == 'foo'}

        [:post, :put].each do |m|
          __send__ m, '/before', obj.to_json, {Angelo::CONTENT_TYPE_HEADER_KEY => Angelo::JSON_TYPE}
          last_response_must_be_json obj.select {|k,v| k == 'foo'}
        end

      end

      it 'runs default and specific before filters' do

        get '/before_bar', obj
        last_response_must_be_json obj_s.select {|k,v| ['foo','bar'].include? k}

        [:post, :put].each do |m|
          __send__ m, '/before_bar', obj.to_json, {Angelo::CONTENT_TYPE_HEADER_KEY => Angelo::JSON_TYPE}
          last_response_must_be_json obj.select {|k,v| ['foo','bar'].include? k}
        end

        get '/before_bat', obj
        last_response_must_be_json obj_s.select {|k,v| ['foo','bat'].include? k}

        [:post, :put].each do |m|
          __send__ m, '/before_bat', obj.to_json, {Angelo::CONTENT_TYPE_HEADER_KEY => Angelo::JSON_TYPE}
          last_response_must_be_json obj.select {|k,v| ['foo','bat'].include? k}
        end

      end

    end

  end

  describe 'after filter' do

    describe 'single default' do

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

    describe 'multiple default' do

      invoked = 0

      define_app do

        after do
          invoked += 2
        end

        after do
          invoked *= 2
        end

        after do
          invoked -= 2
        end

        Angelo::HTTPABLE.each do |m|
          __send__ m, '/after' do
            invoked.to_s
          end
        end

      end

      it 'runs after filters in order' do
        a = %w[0 2 6 14 30]
        b = [2, 6, 14, 30, 62]

        Angelo::HTTPABLE.each_with_index do |m,i|
          __send__ m, '/after', obj
          last_response_must_be_html a[i]
          invoked.must_equal b[i]
        end
      end

    end

    describe 'pathed' do

      invoked = 0

      define_app do

        after do
          invoked += 2
        end

        after '/after_bar' do
          invoked *= 2
        end

        after '/after_bat' do
          invoked -= 4
        end

        Angelo::HTTPABLE.each do |m|
          __send__ m, '/after' do
            invoked.to_s
          end

          __send__ m, '/after_bar' do
            invoked.to_s
          end

          __send__ m, '/after_bat' do
            invoked.to_s
          end
        end

      end

      it 'runs default and specific after filters' do

        a = %w[0 2 4 6 8]
        b = [2, 4, 6, 8, 10]

        Angelo::HTTPABLE.each_with_index do |m,i|
          __send__ m, '/after', obj
          last_response_must_be_html a[i]
          invoked.must_equal b[i]
        end

        c = %w[10 24 52 108 220]
        d = [24, 52, 108, 220, 444]

        Angelo::HTTPABLE.each_with_index do |m,i|
          __send__ m, '/after_bar', obj
          last_response_must_be_html c[i]
          invoked.must_equal d[i]
        end

        e = %w[444 442 440 438 436]
        f = [442, 440, 438, 436, 434]

        Angelo::HTTPABLE.each_with_index do |m,i|
          __send__ m, '/after_bat', obj
          last_response_must_be_html e[i]
          invoked.must_equal f[i]
        end

      end

    end

  end

end
