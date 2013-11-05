require_relative '../spec_helper'

CK = 'ANGELO_CONCURRENCY' # concurrency key
DC = 5                    # default concurrency

describe Angelo::WebsocketResponder do

  let(:concurrency){ ENV.key?(CK) ? ENV[CK].to_i : DC }

  def socket_wait_for path, &block
    Array.new(concurrency).map {|n| Thread.new {socket path, &block}}
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
          client.recv.should eq "hi there #{n}"
        }
      end
    end

    it 'responds on multiple websockets properly' do
      5.times do
        Thread.new do
          socket '/' do |client|
            5.times {|n|
              client.send "hi there #{n}"
              client.recv.should eq "hi there #{n}"
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

      ts = socket_wait_for '/concur' do |client|
        Angelo::HTTPABLE.each do |m|
          client.recv.should eq "from http #{m}"
        end
      end

      sleep 0.1
      Angelo::HTTPABLE.each {|m| __send__ m, '/concur', foo: 'http'}
      ts.each &:join

    end

  end

  describe 'helper contexts' do
    let(:obj){ {'foo' => 'bar'} }
    let(:wait_for_block) { ->(client){ JSON.parse(client.recv).should eq obj}}

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
      ts = socket_wait_for '/', &wait_for_block
      sleep 0.1
      post '/', obj
      ts.each &:join
    end

    it 'handles multiple contexts' do
      ts = socket_wait_for '/', &wait_for_block
      one_ts = socket_wait_for '/one', &wait_for_block
      other_ts = socket_wait_for '/other', &wait_for_block

      sleep 0.1
      post '/one', obj

      ts.each {|t| t.should be_alive}
      one_ts.each &:join
      other_ts.each {|t| t.should be_alive}

      sleep 0.1
      post '/other', obj

      ts.each {|t| t.should be_alive}
      one_ts.each {|t| t.should_not be_alive}
      other_ts.each &:join

      sleep 0.1
      post '/', obj

      ts.each &:join
      one_ts.each {|t| t.should_not be_alive}
      other_ts.each {|t| t.should_not be_alive}
    end

  end
end
