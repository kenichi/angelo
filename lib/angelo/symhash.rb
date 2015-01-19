module Angelo
  class SymHash < Hash
    # Returns a Hash that allows values to be fetched with String or
    # Symbol keys.
    def initialize
      super {|hash,key| hash[key.to_s] if Symbol === key}
    end

    def merge!(other)
      super.tap do |result|
        other.each do |k,v|
          # If any of the merged values are Hashes, replace them with
          # SymHashes all the way down.
          if v.kind_of?(Hash)
            result[k] = self.class.new.merge!(v)
          end
        end
      end
    end

  end
end
