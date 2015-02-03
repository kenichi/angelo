require 'erb'
require 'tilt'

module Angelo
  module Tilt
    module ERB

      DEFAULT_LAYOUT = 'layout.%s.erb'
      DEFAULT_TYPE = :html
      LAYOUTS_DIR = 'layouts'
      ACCEPT_ALL = '*/*'

      # hrm, sneaky
      #
      def self.included base
        base.extend ClassMethods
      end

      module ClassMethods

        @reload_templates = false

        def view_glob *glob
          File.join views_dir, *glob
        end

        def templatify *glob
          Dir[view_glob *glob].reduce({}) do |h,v|
            sym = v.gsub views_dir + File::SEPARATOR, ''
            return h if (block_given? && yield(v))
            sym.gsub! File::SEPARATOR, UNDERSCORE
            sym.gsub! /\.\w+?\.erb$/, EMPTY_STRING
            sym.gsub! /^#{LAYOUTS_DIR}#{UNDERSCORE}/, EMPTY_STRING
            h[sym.to_sym] = ::Tilt::ERBTemplate.new v
            h
          end
        end

        def templates type = DEFAULT_TYPE
          @templates ||= {}
          if reload_templates?
            @templates[type] = load_templates(type)
          else
            @templates[type] ||= load_templates(type)
          end
        end

        def load_templates type = DEFAULT_TYPE
          templatify('**', "*.#{type}.erb") do |v|
            v =~ /^#{LAYOUTS_DIR}#{File::SEPARATOR}/
          end
        end

        def layout_templates type = DEFAULT_TYPE
          if reload_templates?
            @layout_templates = load_layout_templates(type)
          else
            @layout_templates ||= load_layout_templates(type)
          end
        end

        def load_layout_templates type = DEFAULT_TYPE
          templatify LAYOUTS_DIR, "*.#{type}.erb"
        end

        def default_layout type = DEFAULT_TYPE
          @default_layout ||= {}
          if reload_templates?
            @default_layout[type] = load_default_layout(type)
          else
            @default_layout[type] ||= load_default_layout(type)
          end
        end

        def load_default_layout type = DEFAULT_TYPE
          l = view_glob(DEFAULT_LAYOUT % type)
          ::Tilt::ERBTemplate.new l if File.exist? l
        end

        def reload_templates! on = true
          @reload_templates = on
        end

        def reload_templates?
          @reload_templates
        end

      end

      def erb view, opts = {locals: {}}
        type = opts[:type] || template_type
        content_type type
        locals = Hash === opts[:locals] ? opts[:locals] : {}
        render = case view
                 when String
                   ->{ view }
                 when Symbol
                   ->{self.class.templates(type)[view].render self, locals}
                 end
        case opts[:layout]
        when false
          render[]
        when Symbol
          if lt = self.class.layout_templates(type)[opts[:layout]]
            lt.render self, locals, &render
          else
            raise ArgumentError.new "unknown layout - :#{opts[:layout]}"
          end
        else
          if self.class.default_layout(type)
            self.class.default_layout(type).render self, locals, &render
          else
            render[]
          end
        end
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
