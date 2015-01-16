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

        # TODO: remove at 0.4
        warn "[DEPRECATED] Angelo::Tilt::ERB will be included by default in angelo >= 0.4"
        raise "Angelo requires Tilt >= 2.0, you have #{::Tilt::VERSION}" unless ::Tilt::VERSION.to_i >= 2

        base.extend ClassMethods
      end

      module ClassMethods

        def view_glob *glob
          File.join views_dir, *glob
        end

        def templatify *glob
          Dir[view_glob *glob].reduce({}) do |h,v|
            sym = v.gsub views_dir + File::SEPARATOR, ''
            return h if (block_given? && yield(v))
            sym.gsub! File::SEPARATOR, UNDERSCORE
            sym.gsub! /\.\w+?\.erb$/, EMPTY_STRING
            h[sym.to_sym] = ::Tilt::ERBTemplate.new v
            h
          end
        end

        def templates type = DEFAULT_TYPE
          @templates ||= {}
          @templates[type] ||= templatify('**', "*.#{type}.erb") do |v|
            v =~ /^#{LAYOUTS_DIR}#{File::SEPARATOR}/
          end
        end

        def layout_templates type = DEFAULT_TYPE
          @layout_templates ||= templatify LAYOUTS_DIR, "*.#{type}.erb"
        end

        def default_layout type = DEFAULT_TYPE
          @default_layout ||= {}
          if @default_layout[type].nil?
            l = view_glob(DEFAULT_LAYOUT % type)
            @default_layout[type] = ::Tilt::ERBTemplate.new l if File.exist? l
          end
          @default_layout[type]
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
