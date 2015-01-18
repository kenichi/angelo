require_relative '../spec_helper'
require "angelo/symhash"

describe Angelo::SymHash do
  describe ".new" do
    it "returns a Hash" do
      Angelo::SymHash.new.must_be_kind_of Hash
    end
  end

  it "fetches values for Symbols that were inserted with Strings" do
    symhash = Angelo::SymHash.new
    symhash["x"] = "y"
    symhash["x"].must_equal "y"
    symhash[:x].must_equal "y"
  end

  describe "#merge!" do
    it "returns self" do
      symhash = Angelo::SymHash.new
      result = symhash.merge!("one" => "two")
      result.must_be_same_as symhash
    end

    it "recursively merges a Hash into self" do
      hash = {
        "foo" => {
          "bar" => "baz",
          "that" => {
            "holmes" => true,
          },
        },
      }

      symhash = Angelo::SymHash.new.merge!(hash)
      symhash["foo"]["bar"].must_equal "baz"
      symhash[:foo][:bar].must_equal "baz"
      symhash["foo"]["that"]["holmes"].must_equal true
      symhash[:foo][:that][:holmes].must_equal true
    end
  end

end
