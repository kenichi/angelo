module Angelo
  class SymHash < Hash

    # Returns a Hash that allows values to be fetched with String or
    # Symbol keys.
    def initialize h = nil
      super(){|hash,key| hash[key.to_s] if Symbol === key}
      unless h.nil?
        merge! h
        # Replace values that are Hashes with SymHashes, recursively.
        each {|k,v| self[k] = SymHash.new(v) if Hash === v}
      end
    end

  end
end
