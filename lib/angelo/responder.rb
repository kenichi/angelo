module Angelo

  class Responder
    include Celluloid::Logger

    EMPTY_JSON = '{}'.freeze

    class << self

      def symhash
        Hash.new {|hash,key| hash[key.to_s] if Symbol === key }
      end

      def compile! name, &block
        define_method name, &block
        method = instance_method name
        remove_method name
        method
      end

    end

    attr_writer :connection

    def initialize &block
      @response_handler = Responder.compile! :request_handler, &block
    end

    def base= base
      @base = base
      @base.responder = self
    end

    def request= request, do_respond = true
      @params = nil
      @request = request
      begin
        @body = handle_request
        respond if do_respond
      rescue => e
        error e.message
        ::STDERR.puts e.backtrace
        @connection.respond :internal_server_error
      end
    end

    def handle_request
      if @response_handler
        @bound_response_handler ||= @response_handler.bind self
        @bound_response_handler.call
      else
        raise NotImplementedError
      end
    end

    def params
      @params ||= case @request.method
                  when GET
                    (@request.query_string || '').split('&').reduce(Responder.symhash) do |p, kv|
                      key, value = kv.split('=').map {|s| CGI.escape s}
                      p[key] = value
                      p
                    end
                  when POST
                    body = @request.body.to_s
                    body = EMPTY_JSON if body.empty?
                    Responder.symhash.merge! JSON.parse body
                  end
      @params
    end

    def respond headers = {}
      @connection.respond :ok, headers.merge(DEFAULT_RESPONSE_HEADERS), @body
    end

    def method_missing meth, *args
      @base.__send__ meth, *args
    end

  end

end
