require_relative '../spec_helper'

describe Angelo::WebsocketResponder do

  def websocket_wait_for path, latch, expectation, key = :swf, &block
    Reactor.testers[key] = Array.new CONCURRENCY do
      wsh = websocket_helper path
      wsh.on_message = ->(e) {
        expectation[e] if Proc === expectation
        latch.count_down
      }
      wsh.init
      wsh
    end
    action = (key.to_s + '_go').to_sym
    Reactor.define_action action do |n|
      every(0.01){ terminate if Reactor.stop? }
      Reactor.testers[key][n].go
    end
    Reactor.unstop!
    CONCURRENCY.times {|n| $reactor.async.__send__(action, n)}

    sleep 0.01 * CONCURRENCY
    yield

    Reactor.testers[key].map &:close
    Reactor.stop!
    Reactor.testers.delete key
    Reactor.remove_action action
  end

  describe 'basics' do

    define_app do
      websocket '/' do |ws|
        while msg = ws.read do
          ws.write msg
        end
      end
    end

    it 'responds on websockets properly' do
      websocket_helper '/' do |wsh|
        latch = CountDownLatch.new 500

        wsh.on_message = ->(e) {
          assert_match /hi there \d/, e.data
          latch.count_down
        }

        wsh.init
        Reactor.testers[:tester] = wsh
        Reactor.define_action :go do
          every(0.01){ terminate if Reactor.stop? }
          Reactor.testers[:tester].go
        end
        Reactor.unstop!
        $reactor.async.go

        500.times {|n| wsh.text "hi there #{n}"}
        latch.wait

        Reactor.stop!
        Reactor.testers.delete :tester
        Reactor.remove_action :go
      end
    end

    it 'responds on multiple websockets properly' do
      latch = CountDownLatch.new CONCURRENCY * 500

      Reactor.testers[:wshs] = Array.new(CONCURRENCY).map do
        wsh = websocket_helper '/'
        wsh.on_message = ->(e) {
          assert_match /hi there \d/, e.data
          latch.count_down
        }
        wsh.init
        wsh
      end

      Reactor.define_action :go do |n|
        every(0.01){ terminate if Reactor.stop? }
        Reactor.testers[:wshs][n].go
      end
      Reactor.unstop!
      CONCURRENCY.times {|n| $reactor.async.go n}

      sleep 0.01 * CONCURRENCY

      ActorPool.define_action :go do |n|
        500.times {|x| Reactor.testers[:wshs][n].text "hi there #{x}"}
      end
      CONCURRENCY.times {|n| $pool.async.go n}
      latch.wait

      Reactor.testers[:wshs].map &:close
      Reactor.stop!
      Reactor.testers.delete :wshs
      Reactor.remove_action :go

      ActorPool.remove_action :go
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

      websocket '/concur' do |ws|
        websockets << ws
      end

    end

    it 'works with http requests' do

      latch = CountDownLatch.new CONCURRENCY * Angelo::HTTPABLE.length

      expectation = ->(e){
        assert_match /from http (#{Angelo::HTTPABLE.map(&:to_s).join('|')})/, e.data
      }

      websocket_wait_for '/concur', latch, expectation do
        Angelo::HTTPABLE.each {|m| __send__ m, '/concur', foo: 'http'}
        latch.wait
      end

    end

  end

  describe 'helper contexts' do
    let(:obj){ {'foo' => 'bar'} }
    let(:wait_for_block){ ->(e){ assert_equal obj, JSON.parse(e.data) }}

    define_app do

      post '/' do
        websockets.each {|ws| ws.write params.to_json}
        ''
      end

      websocket '/' do |ws|
        websockets << ws
        while msg = ws.read do
          ws.write msg.to_json
        end
      end

      post '/one' do
        websockets[:one].each {|ws| ws.write params.to_json}
        ''
      end

      websocket '/one' do |ws|
        websockets[:one] << ws
        while msg = ws.read do
          ws.write msg.to_json
        end
      end

      post '/other' do
        websockets[:other].each {|ws| ws.write params.to_json}
        ''
      end

      websocket '/other' do |ws|
        websockets[:other] << ws
        while msg = ws.read do
          ws.write msg.to_json
        end
      end

    end

    it 'handles single context' do
      latch = CountDownLatch.new CONCURRENCY
      websocket_wait_for '/', latch, wait_for_block do
        post '/', obj
        latch.wait
      end
    end

    it 'handles multiple contexts' do

      latch = CountDownLatch.new CONCURRENCY

      Reactor.testers[:hmc] = Array.new(CONCURRENCY).map do
        wsh = websocket_helper '/'
        wsh.on_message = ->(e) {
          wait_for_block[e]
          latch.count_down
        }
        wsh.init
        wsh
      end

      one_latch = CountDownLatch.new CONCURRENCY

      Reactor.testers[:hmc_one] = Array.new(CONCURRENCY).map do
        wsh = websocket_helper '/one'
        wsh.on_message = ->(e) {
          wait_for_block[e]
          one_latch.count_down
        }
        wsh.init
        wsh
      end

      other_latch = CountDownLatch.new CONCURRENCY

      Reactor.testers[:hmc_other] = Array.new(CONCURRENCY).map do
        wsh = websocket_helper '/other'
        wsh.on_message = ->(e) {
          wait_for_block[e]
          other_latch.count_down
        }
        wsh.init
        wsh
      end

      Reactor.define_action :go do |k, n|
        Reactor.testers[k][n].go
      end
      Reactor.unstop!
      CONCURRENCY.times do |n|
        [:hmc, :hmc_one, :hmc_other].each do |k|
          $reactor.async.go k, n
        end
      end

      sleep 0.01 * CONCURRENCY

      post '/one', obj
      one_latch.wait
      post '/', obj
      latch.wait
      post '/other', obj
      other_latch.wait

      [:hmc, :hmc_one, :hmc_other].each do |k|
        Reactor.testers[k].map &:close
      end
      Reactor.stop!
      [:hmc, :hmc_one, :hmc_other].each do |k|
        Reactor.testers.delete k
      end
      Reactor.remove_action :go
    end

  end

end
