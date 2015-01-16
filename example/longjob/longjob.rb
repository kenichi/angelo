$:.unshift File.expand_path '../../../lib', __FILE__

require 'bundler'
Bundler.require

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

  log_level = Logger::DEBUG

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
    if job_exists? params[:id]
      websockets << ws
      async :track_progress, params[:id], ws
    else
      ws.write({progress: 'done'}.to_json)
      ws.close
    end
  end

  eventsource '/progress/:id' do |es|
    if job_exists? params[:id]
      async :track_progress, params[:id], es
    else
      es.write sse_event(:progress, progress: 'done')
      es.close
    end
  end

  # ---

  task :track_progress do |id, s|
    case s
    when Reel::WebSocket
      catch :done do
        ::Redis.new(driver: :celluloid).subscribe(REDIS_CHANNEL % id) do |on|
          on.message do |channel, msg|
            s.write msg
            throw :done if JSON.parse(msg)['progress'] == 100
          end
        end
      end
      s.write({progress: 'done'}.to_json)
      s.close

    when Celluloid::IO::TCPSocket
      catch :done do
        ::Redis.new(driver: :celluloid).subscribe(REDIS_CHANNEL % id) do |on|
          on.message do |channel, msg|
            s.write sse_event :progress, msg
            throw :done if JSON.parse(msg)['progress'] == 100
          end
        end
      end
      s.write sse_event :progress, progress: 'done'
      s.close
    end
  end

  def job_exists? id
    @@redis.sismember :jobs, id
  end

end

Longjob.run!
