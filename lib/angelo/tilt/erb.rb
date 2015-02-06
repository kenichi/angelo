require 'erb'
require 'tilt'

module Angelo
  module Tilt
    module ERB

      DEFAULT_LAYOUT = 'layout.%s'
      DEFAULT_TYPE = :html
      LAYOUTS_DIR = 'layouts'
      ACCEPT_ALL = '*/*'

      def erb view, opts = {}
        type = opts.delete(:type) || template_type
        content_type type

        if view.is_a? Symbol
          view = :"#{view}.#{type}"
        end

        layout =
          case opts[:layout]
          when false
            false
          when Symbol
            :"#{LAYOUTS_DIR}/#{layout}"
          else
            :"#{DEFAULT_LAYOUT % type}"
          end

        _erb view, layout: layout, locals: opts[:locals]
      end

      def template_type
        accept = request.headers[ACCEPT_REQUEST_HEADER_KEY]
        mt = if accept.nil? or accept == ACCEPT_ALL
               MIME::Types[headers[CONTENT_TYPE_HEADER_KEY]]
             else
               MIME::Types[request.headers[ACCEPT_REQUEST_HEADER_KEY]]
             end
        mt.first.extensions.first.to_sym
      rescue
        DEFAULT_TYPE
      end

    end
  end
end
