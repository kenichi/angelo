require_relative '../spec_helper'

describe Angelo::Base do
  describe 'websocket handling' do

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

    it 'handles websockets concurrently with http requests' do

      ts = []
      5.times {|n|
        ts << Thread.new {
          socket '/concur' do |client|
            Angelo::HTTPABLE.each do |m|
              client.recv.should eq "from http #{m}"
            end
          end
        }
      }

      sleep 0.1
      Angelo::HTTPABLE.each {|m| __send__ m, '/concur', foo: 'http'}
      ts.map &:join

    end

  end
end
