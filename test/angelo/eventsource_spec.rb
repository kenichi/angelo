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
