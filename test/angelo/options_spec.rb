require_relative '../spec_helper'

describe "parse_options" do
  describe "parses" do
    it "-p port" do
      Class.new(Angelo::Base) do
        parse_options("-p 12345".split)
        port.must_equal 12345
      end
    end

    it "-o addr" do
      Class.new(Angelo::Base) do
        parse_options("-o 3.2.1.0".split)
        addr.must_equal "3.2.1.0"
      end
    end
  end
end
