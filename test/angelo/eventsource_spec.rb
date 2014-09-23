require_relative '../spec_helper'

describe Angelo::Responder::Eventsource do

  describe 'route builder' do

    describe 'basics' do

      define_app do

        eventsource '/msg' do |c|
          c.message 'hi'
          c.close
        end

        eventsource '/event' do |c|
          c.event :sse, 'bye'
          c.close
        end

        eventsource '/headers', foo: 'bar' do |c|
          c.event :sse, 'headers'
          c.close
        end

      end

      it 'sends messages' do
        get_sse '/msg' do |msg|
          msg.must_equal "data: hi\n\n"
        end
      end

      it 'sends events' do
        get_sse '/event' do |msg|
          msg.must_equal "event: sse\ndata: bye\n\n"
        end
      end

      it 'accepts extra headers hash as second optional parameter' do
        get_sse '/headers' do |msg|
          msg.must_equal "event: sse\ndata: headers\n\n"
        end
        last_response.headers['Foo'].must_equal 'bar'
      end

    end

    describe 'error handling' do

      define_app do

        before '/msg' do
          raise 'wrong'
        end

        before '/other' do
          raise Angelo::RequestError.new sse_message('foo'), 200
        end

        eventsource '/msg' do |c|
          c.message 'hi'
          c.close
        end

        eventsource '/other' do |c|
          c.message 'other'
          c.close
        end

      end

      it 'handles exceptions in before blocks' do
        get_sse '/msg' do |msg|
          msg.must_equal "wrong"
        end
        last_response.status.must_equal 500
      end

      it 'handles RequestError exceptions in before blocks' do
        get_sse '/other' do |msg|
          msg.must_equal "data: foo\n\n"
        end
        last_response.status.must_equal 200
      end

    end

  end

end

describe 'eventsource helper' do

  define_app do

    get '/msg' do
      eventsource do |c|
        c.write sse_message 'hi'
        c.close
      end
    end

    get '/event' do
      eventsource do |c|
        c.write sse_event :sse, 'bye'
        c.close
      end
    end

    get '/headers' do
      headers foo: 'bar'
      eventsource do |c|
        c.write sse_event :sse, 'headers'
        c.close
      end
    end

  end

  it 'sends messages' do
    get_sse '/msg' do |msg|
      msg.must_equal "data: hi\n\n"
    end
  end

  it 'sends events' do
    get_sse '/event' do |msg|
      msg.must_equal "event: sse\ndata: bye\n\n"
    end
  end

  it 'allows headers to be set outside block' do
    get_sse '/headers' do |msg|
      msg.must_equal "event: sse\ndata: headers\n\n"
    end
    last_response.headers['Foo'].must_equal 'bar'
  end

end
