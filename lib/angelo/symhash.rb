module Angelo
  class SymHash < Hash
    # Returns a Hash that allows values to be fetched with String or
    # Symbol keys.  If a hash is passed in, recursively creates a new
    # SymHash from it.
    def self.new(hash=nil)
      if hash.nil?
        Hash.new {|hash,key| hash[key.to_s] if Symbol === key}
      else
        create_symhash(hash)
      end
    end

    private

    def self.create_symhash(other)
      new.merge!(other).tap do |symhash|
        symhash.each do |k,v|
          if v.kind_of?(Hash)
            symhash[k] = create_symhash(v)
          end
        end
      end
    end

  end
end
