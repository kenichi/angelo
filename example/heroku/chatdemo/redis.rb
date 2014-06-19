module ChatDemo
  module Redis

    # parameters to feed into ConnectionPool
    #
    POOL_CONF = {
      timeout: 5,
      size: 16
    }

    # where to connect to redis
    #
    URI = ::URI.parse ENV['REDISCLOUD_URL'] || 'redis://127.0.0.1:6379/'

    # channel names
    #
    CHANNEL_KEY = 'chat:%s'

    class << self

      # return a new redis connection
      #
      def new_redis
        ::Redis.new driver: :celluloid,
                    host: URI.host,
                    port: URI.port,
                    password: URI.password
      end

      # run a redis command through the connection pool
      #
      def with &block
        @redis ||= ConnectionPool.new(POOL_CONF){ new_redis }
        @redis.with &block
      end

    end
  end
end
