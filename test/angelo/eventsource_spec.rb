require_relative '../spec_helper'

describe Angelo::Responder::Eventsource do

  describe 'route builder' do

    define_app do

      eventsource '/msg' do |c|
        c.write sse_message 'hi'
        c.close
      end

      eventsource '/event' do |c|
        c.write sse_event :sse, 'bye'
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

    get '/headers_out' do
      headers foo: 'bar'
      eventsource do |c|
        c.write sse_event :sse, 'headers_out'
        c.close
      end
    end

    get '/headers_in' do
      eventsource do |c|
        headers foo: 'bar'
        c.write sse_event :sse, 'headers_in'
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
    get_sse '/headers_out' do |msg|
      msg.must_equal "event: sse\ndata: headers_out\n\n"
    end
    last_response.headers['foo'].must_equal 'bar'
  end

  it 'allows headers to be set inside block' do
    get_sse '/headers_in' do |msg|
      msg.must_equal "event: sse\ndata: headers_in\n\n"
    end
    last_response.headers['foo'].must_equal 'bar'
  end

end
