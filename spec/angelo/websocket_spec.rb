require_relative '../spec_helper'

CK = 'ANGELO_CONCURRENCY' # concurrency key
DC = 5                    # default concurrency

include Celluloid::Logger

describe Angelo::WebsocketResponder do

  let(:concurrency){ ENV.key?(CK) ? ENV[CK].to_i : DC }

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

      ts = []
      concurrency.times {|n|
        ts << Thread.new {
          socket '/concur' do |client|
            Angelo::HTTPABLE.each do |m|
              client.recv.should eq "from http #{m}"
            end
          end
        }
      }

      info 'hi'
      sleep 0.1
      Angelo::HTTPABLE.each {|m| __send__ m, '/concur', foo: 'http'}
      ts.map &:join

    end

  end

  describe 'helper contexts' do
    let(:obj){ {'foo' => 'bar'} }

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
      ts = []
      concurrency.times {|n|
        ts << Thread.new {
          socket '/' do |client|
            JSON.parse(client.recv).should eq obj
          end
        }
      }

      sleep 0.1
      post '/', obj
      ts.map &:join
    end

    it 'handles multiple contexts' do
      one_ts = []
      (concurrency / 2).times {|n|
        one_ts << Thread.new {
          socket '/one' do |client|
            JSON.parse(client.recv).should eq obj
          end
        }
      }

      other_ts = []
      (concurrency / 2).times {|n|
        other_ts << Thread.new {
          socket '/other' do |client|
            JSON.parse(client.recv).should eq obj
          end
        }
      }

      info 'hi'
      sleep 0.1
      post '/one', obj
      other_ts.map {|t| t.should be_alive}
      one_ts.map &:join

      info 'bye'
      sleep 0.1
      post '/other', obj
      other_ts.map &:join
    end

  end
end
