$:.unshift File.expand_path '../../../lib', __FILE__

require 'bundler'
Bundler.require

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
    @redis.sadd :jobs, @id
  end

  def go
    10.times do |n|
      sleep rand(5) + 1
      @redis.publish REDIS_CHANNEL % @id, {progress: (n+1)*10}.to_json
    end
    @redis.srem :jobs, @id
  end

end

class Longjob < Angelo::Base
  include Angelo::Mustermann

  @@redis = ::Redis.new driver: :celluloid

  get '/' do
    redirect '/longjob.html'
  end

  post '/start' do
    content_type :json
    @job = Job.new
    @job.async.go
    {id: @job.id}
  end

  websocket '/progress/:id' do |ws|
    if @@redis.sismember :jobs, params[:id]
      websockets << ws
      async :track_progress, params[:id], ws
    else
      ws.close
    end
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
