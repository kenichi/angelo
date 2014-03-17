require_relative '../spec_helper'

CK = 'ANGELO_CONCURRENCY' # concurrency key
DC = 5                    # default concurrency

# https://gist.github.com/tkareine/739662
#
class CountDownLatch
  attr_reader :count

  def initialize(to)
    @count = to.to_i
    raise ArgumentError, "cannot count down from negative integer" unless @count >= 0
    @lock = Mutex.new
    @condition = ConditionVariable.new
  end

  def count_down
    @lock.synchronize do
      @count -= 1 if @count > 0
      @condition.broadcast if @count == 0
    end
  end

  def wait
    @lock.synchronize do
      @condition.wait(@lock) while @count > 0
    end
  end

end

describe Angelo::WebsocketResponder do

  let(:concurrency){ ENV.key?(CK) ? ENV[CK].to_i : DC }

  def socket_wait_for path, latch, &block
    Array.new(concurrency).map do |n|
      Thread.new do
        socket path do |client|
          latch.count_down
          block[client]
        end
      end
    end
  end

  describe 'basics' do

    define_app do
      socket '/' do |ws|
        while msg = ws.read do
          ws.write msg
        end
      end
    end

    it 'responds on websockets properly' do
      socket '/' do |client|
        5.times {|n|
          client.send "hi there #{n}"
          expect(client.recv).to eq("hi there #{n}")
        }
      end
    end

    it 'responds on multiple websockets properly' do
      concurrency.times do
        Thread.new do
          socket '/' do |client|
            5.times {|n|
              client.send "hi there #{n}"
              expect(client.recv).to eq("hi there #{n}")
            }
          end
        end
      end
    end

  end

  describe 'concurrency' do

    define_app do

      Angelo::HTTPABLE.each do |m|
        __send__ m, '/concur' do
          websockets.each do |ws|
            msg = "from #{params ? params[:foo] : 'http'} #{m.to_s}"
            ws.write msg
          end
          ''
        end
      end

      socket '/concur' do |ws|
        websockets << ws
      end

    end

    it 'works with http requests' do

      latch = CountDownLatch.new concurrency
      ts = socket_wait_for '/concur', latch do |client|
        Angelo::HTTPABLE.each do |m|
          expect(client.recv).to eq("from http #{m}")
        end
      end

      latch.wait
      Angelo::HTTPABLE.each {|m| __send__ m, '/concur', foo: 'http'}
      ts.each &:join

    end

  end

  describe 'helper contexts' do
    let(:obj){ {'foo' => 'bar'} }
    let(:wait_for_block){ ->(client){ expect(JSON.parse(client.recv)).to eq(obj) }}

    define_app do

      post '/' do
        websockets.each {|ws| ws.write params.to_json}
        ''
      end

      socket '/' do |ws|
        websockets << ws
        while msg = ws.read do
          ws.write msg.to_json
        end
      end

      post '/one' do
        websockets[:one].each {|ws| ws.write params.to_json}
        ''
      end

      socket '/one' do |ws|
        websockets[:one] << ws
        while msg = ws.read do
          ws.write msg.to_json
        end
      end

      post '/other' do
        websockets[:other].each {|ws| ws.write params.to_json}
        ''
      end

      socket '/other' do |ws|
        websockets[:other] << ws
        while msg = ws.read do
          ws.write msg.to_json
        end
      end

    end

    it 'handles single context' do
      latch = CountDownLatch.new concurrency
      ts = socket_wait_for '/', latch, &wait_for_block
      latch.wait
      post '/', obj
      ts.each &:join
    end

    it 'handles multiple contexts' do
      latch = CountDownLatch.new concurrency
      one_latch = CountDownLatch.new concurrency
      other_latch = CountDownLatch.new concurrency

      ts = socket_wait_for '/', latch, &wait_for_block
      latch.wait
      one_ts = socket_wait_for '/one', one_latch, &wait_for_block
      one_latch.wait
      other_ts = socket_wait_for '/other', other_latch, &wait_for_block
      other_latch.wait

      post '/one', obj

      ts.each {|t| t.should be_alive}
      one_ts.each &:join
      other_ts.each {|t| t.should be_alive}

      post '/other', obj

      ts.each {|t| t.should be_alive}
      one_ts.each {|t| t.should_not be_alive}
      other_ts.each &:join

      post '/', obj

      ts.each &:join
      one_ts.each {|t| t.should_not be_alive}
      other_ts.each {|t| t.should_not be_alive}
    end

  end

end
