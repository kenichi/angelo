require "angelo"

module Angelo
  class Base
    @angelo_main = true

    # Takes a block and/or modules that define methods that can be
    # used from within request handlers.  Methods can also be defined
    # at the top level but they get defined as Object instance methods
    # which isn't good.

    module DSL
      def helpers(*args, &block)
        args.each do |mod|
          include(mod)
        end
        block && class_exec(&block)
      end
    end

  end
end

# The intent here is to add the DSL to the top-level object "main" by
# creating an anonymous Angelo::Base subclass and forwarding the DSL
# methods to it from the top-level object.  Then run the app at exit.
#
# If angelo/main is required from somewhere other than the top level,
# all bets are off.

if self.to_s == "main"
  # We are probably at the top level.

  @angelo_app = Class.new(Angelo::Base)

  Angelo::Base::DSL.instance_methods.each do |bim|
    define_singleton_method bim do |*a, &block|
      @angelo_app.__send__ bim, *a, &block
    end
  end

  at_exit do
    # Don't run @angelo_app on uncaught exceptions including exit
    # being called which raises SystemExit.  The rationale being that
    # exit means exit, not "run the server".
    if $!.nil?
      @angelo_app.run!
    end
  end
end
