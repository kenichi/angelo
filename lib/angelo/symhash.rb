module Angelo
  class SymHash < Hash
    # Returns a Hash that allows values to be fetched with String or
    # Symbol keys.
    def initialize
      super {|hash,key| hash[key.to_s] if Symbol === key}
    end
  end
end
