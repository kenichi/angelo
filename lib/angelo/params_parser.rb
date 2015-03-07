require 'cgi'

module Angelo

  class FormEncodingError < StandardError; end

  module ParamsParser

    EMPTY_JSON = '{}'

    def parse_formencoded str
      str.split(AMPERSAND).reduce(SymHash.new) do |p, kv|
        key, value = kv.split(EQUALS).map {|s| CGI.unescape s}
        p[key] = value
        p
      end
    end

    def parse_query_string
      parse_formencoded(request.query_string || EMPTY_STRING)
    end

    def parse_post_body
      body = request_body rescue request.body.to_s
      case
      when form_encoded?
        parse_formencoded body
      when json? && !body.empty?
        parsed_body = JSON.parse body
        parsed_body = SymHash.new parsed_body if Hash === parsed_body
        parsed_body
      else
        {}
      end
    end

    def parse_query_string_and_post_body
      parsed_body = parse_post_body
      case parsed_body
      when Hash
        parse_query_string.merge! parse_post_body
      when Array
        self.request_body = parsed_body
        parse_query_string
      end
    end

    def form_encoded?
      content_type? FORM_TYPE
    end

    def json?
      content_type? JSON_TYPE
    end

    def content_type? type
      if request.headers[CONTENT_TYPE_HEADER_KEY]
        request.headers[CONTENT_TYPE_HEADER_KEY].split(SEMICOLON).include? type
      else
        nil
      end
    end

  end

  class SymHash < Hash

    # Returns a Hash that allows values to be fetched with String or
    # Symbol keys.
    def initialize h = nil
      super(){|hash,key| hash[key.to_s] if Symbol === key}
      unless h.nil?
        merge! h

        # Replace values that are Hashes with SymHashes, recursively.
        each do |k,v|
          self[k] = case v
                    when Hash
                      SymHash.new(v)
                    when Array
                      v.map {|e| Hash === e ? SymHash.new(e) : e}
                    else
                      v
                    end
        end

      end
    end

  end

end
