require 'erb'
require 'tilt'

module Angelo
  module Tilt
    module ERB

      # hrm, sneaky
      #
      def self.included base
        base.extend ClassMethods
      end

      module ClassMethods

        DEFAULT_LAYOUT = 'layout.html.erb'

        def view_glob *glob
          File.join view_dir, *glob
        end

        def templatify *glob
          Dir[view_glob *glob].reduce({}) do |h,v|
            sym = v.gsub view_dir + '/', ''
            return h if (block_given? && yield(v))
            sym.gsub! '/', '_'
            sym.gsub! /\.\w+?\.erb$/, ''
            h[sym.to_sym] = ::Tilt::ERBTemplate.new v
            h
          end
        end

        def templates
          @templates ||= templatify('**', '*.erb'){|v| v =~ /^layouts\//}
          @templates
        end

        def layout_templates
          @layout_templates ||= templatify 'layouts', '*.erb'
          @layout_templates
        end

        def default_layout
          if @default_layout.nil?
            l = view_glob(DEFAULT_LAYOUT)
            @default_layout = ::Tilt::ERBTemplate.new l if File.exist? l
          end
          @default_layout
        end

      end

      def erb view, opts = {locals: {}}
        locals = Hash === opts[:locals] ? opts[:locals] : {}
        render = case view
                 when String
                   ->{ view }
                 when Symbol
                   ->{self.class.templates[view].render self, locals}
                 end
        case opts[:layout]
        when false
          render[]
        when Symbol
          if lt = self.class.layout_templates[opts[:layout]]
            lt.render self, locals, &render
          else
            raise ArgumentError.new "unknown layout - :#{opts[:layout]}"
          end
        else
          if self.class.default_layout
            self.class.default_layout.render self, locals, &render
          else
            render[]
          end
        end
      end

    end
  end
end
