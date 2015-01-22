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

  require "forwardable"
  self.extend Forwardable
  @angelo_app = Class.new(Angelo::Base)
  self.def_delegators :@angelo_app, *Angelo::Base::DSL.instance_methods
end
