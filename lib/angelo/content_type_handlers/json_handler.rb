module Angelo
  class JSONHandler
    def handle(body)
      case body
      when String
        JSON.parse body
        body
      when Hash
        body.to_json
      end
    end

    def handle_error(error)
      case error
      when String, Hash
        handle({error: error})
      else
        handle({error: error.message})
      end
    end
  end
end
