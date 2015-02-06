require 'tilt'

module Angelo
  module Templates

    # When this code refers to Tilt, use ::Tilt not Angelo::Tilt.

    Tilt = ::Tilt

    # Add instance methods to render views with each template engine
    # I'm using.  The methods are called "haml", "markdown", etc.

    # They render files (Symbols) or Strings, with no frills other
    # than locals.  Files must be in the self.class.views_dir
    # directory, with an extension that Tilt maps to the
    # template_type.

    # Angelo::Tilt::ERB includes an erb method built on top of _erb
    # (below) which provides slightly differnet semantics.  For
    # compatibilty, we don't overwrite that method here and instead
    # define _erb.  At least for now.

    [:haml, :markdown].each do |template_type|
      define_method(template_type) do |view, opts = {}|
        render(template_type, view, opts)
      end
    end

    def _erb(view, opts = {})
      render(:erb, view, opts)
    end

    private

    def render(template_type, view, opts = {})
      # Extract the options that belong to us.  Any remaining options
      # will be passed to the engine when the template is instantiated.

      locals = opts.delete(:locals) || {}
      layout_engine = opts.delete(:layout_engine) || template_type
      layout = 
        if opts.has_key?(:layout)
          layout = opts.delete(:layout)
          case layout
          when true
            :layout
          when nil
            false
          else
            layout
          end
        else
          # Use the default layout.
          :layout
        end

      template = self.class.get_template(template_type, view, self.class.views_dir, opts)
      if !template
        raise ArgumentError, "Can't find template `#{view}' of type `#{template_type}'"
      end

      render = ->{ template.render(self, locals) }
      if layout
        layout_template = self.class.get_template(layout_engine, layout,
            File.join(self.class.views_dir), opts)
      end
      if layout_template
        layout_template.render(self, &render)
      else
        render.call
      end
    end

    def self.included(klass)
      klass.extend TemplateCaching
    end

    module TemplateCaching
      # Create a template cache that all subclasses of Angelo::Base
      # will share.  reload_templates is per-subclass.

      @@template_cache = Tilt::Cache.new

      def reload_templates!(on = true)
        @reload_templates = on
      end

      def reload_templates?
        @reload_templates
      end

      def get_template(*args)
        if reload_templates?
          instantiate_template(*args)
        else
          # Use :not_found as a cachable marker that the file isn't found.
          template = @@template_cache.fetch(*args) do
            instantiate_template(*args) || :not_found
          end
          template == :not_found ? nil : template
        end
      end

      private

      def instantiate_template(template_type, view, views_dir, opts)
        case view
        when Symbol
          instantiate_template_from_file(template_type, view.to_s, views_dir, opts)
        when String
          instantiate_template_from_string(template_type, view, opts)
        else
          raise ArgumentError, "view must be a Symbol or a String"
        end
      end

      def instantiate_template_from_file(template_type, view, views_dir, opts)
        # Find a file in the views directory with a correct extension
        # for this template_type.
        file = find_view_file_for_template_type(views_dir, view, template_type)
        if file
          # Use absolute filenames so backtraces have absolute filenames.
          absolute_file = File.expand_path(file)
          Tilt.new(absolute_file, opts)
        end
      end

      def instantiate_template_from_string(template_type, string, opts)
        # To make Tilt use a String as a template we pass Tilt.new a
        # block that returns the String.  Passing a block makes
        # Tilt.new ignore the file argument.  Except the file argument
        # is still used to figure out which template engine to use.
        # Fortunately we can just pass template_type, except the file
        # argument needs to respond to to_str and symbols don't
        # respond to that so we convert it to a String.
        Tilt.new(template_type.to_s, opts) {string}
      end

      def find_view_file_for_template_type(views, name, template_type)
        template_class = Tilt[template_type]
        exts = Tilt.default_mapping.extensions_for(template_class).uniq
        filenames = exts.map{|ext| File.join(views, "#{name}.#{ext}")}
        filenames.find{|f| File.exists?(f)}
      end
    end

  end
end
