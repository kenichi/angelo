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
      body = request.body.to_s
      qs = parse_query_string
      case
      when form_encoded?
        body = parse_formencoded body
        qs.merge! body
      when json?
        body = EMPTY_JSON if body.empty?
        qs.merge! SymHash.new JSON.parse body
      else
        qs
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
        each {|k,v| self[k] = SymHash.new(v) if Hash === v}
      end
    end

  end

end
