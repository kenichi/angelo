require_relative '../spec_helper'
require 'angelo/main'

describe "angelo/main" do
  helpers = Module.new do
    def self.with_args(args, &block)
      orig_argv = ARGV.dup
      ARGV.replace(args.split)
      begin
        block.call
      ensure
        ARGV.replace(orig_argv)
      end
    end
  end

  describe "parses" do
    it "-p port" do
      helpers.with_args("-p 12345") do
        klass = Class.new(Angelo::Base)
        klass.port.must_equal 12345
      end
    end

    it "-o addr" do
      helpers.with_args("-o 3.2.1.0") do
        klass = Class.new(Angelo::Base)
        klass.addr.must_equal "3.2.1.0"
      end
    end
  end

  it "uses defaults if not specified" do
    helpers.with_args("") do
      klass = Class.new(Angelo::Base)
      klass.port.must_equal Angelo::DEFAULT_PORT
      klass.addr.must_equal Angelo::DEFAULT_ADDR
    end
  end

  it "doesn't alter ARGV" do
    helpers.with_args("-p 1234 -o 109.87.65.43") do
      pre_args = ARGV.dup
      Class.new(Angelo::Base)
      ARGV.must_equal pre_args
    end
  end
end
