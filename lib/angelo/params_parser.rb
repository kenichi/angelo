require 'cgi'

module Angelo

  module ParamsParser

    EMPTY_JSON = '{}'
    SEMICOLON = ';'

    def parse_formencoded str
      str.split('&').reduce(Responder.symhash) do |p, kv|
        key, value = kv.split('=').map {|s| CGI.unescape s}
        p[key] = value
        p
      end
    end

    def parse_query_string
      parse_formencoded(request.query_string || '')
    end

    def parse_post_body
      body = request.body.to_s
      case
      when form_encoded?
        body = parse_formencoded body
      when json?
        body = EMPTY_JSON if body.empty?
        body = JSON.parse body
      end
      parse_query_string.merge! body
    end

    def form_encoded?
      content_type? FORM_TYPE
    end

    def json?
      content_type? JSON_TYPE
    end

    def content_type? type
      request.headers[CONTENT_TYPE_HEADER_KEY].split(SEMICOLON).include? type
    end

  end

end
