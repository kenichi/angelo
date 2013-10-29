require 'cgi'

module Angelo

  class Responder
    include Celluloid::Logger
    include ParamsParser

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

    def request= request
      @params = nil
      @request = request
      handle_request
      respond
    end

    def handle_request
      begin
        if @response_handler
          @bound_response_handler ||= @response_handler.bind self
          @body = @bound_response_handler.call || ''
        else
          raise NotImplementedError
        end
      rescue => e
        error e.message
        ::STDERR.puts e.backtrace
        @connection.respond :internal_server_error
      end
    end

    def params
      @params ||= case @request.method
                  when GET;  parse_query_string
                  when POST; parse_post_body
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

  class WebsocketResponder < Responder

    def params
      @params ||= parse_query_string
      @params
    end

    def request= request
      @params = nil
      @request = request
      @websocket = @request.websocket
      handle_request
    end

    def handle_request
      begin
        if @response_handler
          @bound_response_handler ||= @response_handler.bind self
          @bound_response_handler[@websocket]
        else
          raise NotImplementedError
        end
      rescue IOError => ioe
        if ioe.message == 'closed stream'
          debug "socket closed!"
          @websocket.close
          @base.websockets.delete @websocket
        else
          raise ioe
        end
      rescue => e
        error e.message
        ::STDERR.puts e.backtrace
        @connection.close
      end
    end

  end

end
