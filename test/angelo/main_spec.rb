require_relative '../spec_helper'
require 'angelo/main'

describe "angelo/main" do
  describe "parses" do
    def with_args(args, &block)
      orig_argv = ARGV.dup
      begin
        ARGV.replace(args.split)
        block.call
      ensure
        ARGV.replace(orig_argv)
      end
    end

    it "-p port" do
      with_args("-p 12345") do
        klass = Class.new(Angelo::Base)
        klass.port.must_equal 12345
      end
    end

    it "-o addr" do
      with_args("-o 3.2.1.0") do
        klass = Class.new(Angelo::Base)
        klass.addr.must_equal "3.2.1.0"
      end
    end
  end
end
