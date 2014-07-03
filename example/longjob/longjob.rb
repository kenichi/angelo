$:.unshift File.expand_path '../../../lib', __FILE__

require 'bundler'
Bundler.require

require 'angelo/tilt/erb'
require 'angelo/mustermann'

REDIS_CHANNEL = 'progress:%s'
ID_POSSIBLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

def generate_id length
  Array.new(length).map {ID_POSSIBLE[rand ID_POSSIBLE.length]}.join
end

class Job
  include Celluloid

  attr_reader :id

  def initialize
    @id = generate_id(4)
    @redis = ::Redis.new driver: :celluloid
  end

  def go
    10.times do |n|
      sleep 3 # work hard for 3 seconds! :)
      @redis.publish REDIS_CHANNEL % @id, {progress: (n+1)*10}.to_json
    end
  end

end

class Longjob < Angelo::Base
  include Angelo::Tilt::ERB
  include Angelo::Mustermann

  get '/' do
    erb :index
  end

  post '/start' do
    content_type :json
    @job = Job.new
    @job.async.go
    {id: @job.id}
  end

  websocket '/progress/:id' do |ws|
    websockets << ws
    async :track_progress, params[:id], ws
  end

  task :track_progress do |id, ws|
    catch :done do
      ::Redis.new(driver: :celluloid).subscribe(REDIS_CHANNEL % id) do |on|
        on.message do |channel, msg|
          ws.write msg
          throw :done if JSON.parse(msg)['progress'] == 100
        end
      end
    end
    ws.close
  end

end

Longjob.run
