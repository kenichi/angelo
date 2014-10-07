require_relative '../spec_helper'

describe Angelo::Stash do

  describe 'error handling' do

    class ErrorSocket

      def read *args
        raise IOError
      end

      def closed?
        true
      end

    end

    class TestStash
      extend Angelo::Stash::ClassMethods
      include Angelo::Stash

      def << s
        peeraddrs[s] = [nil, 'hi from tests']
        stashes[@context] << s
      end

    end

    it 'does not skip live sockets when removing dead sockets' do
      err_sock = ErrorSocket.new

      good_sock = Minitest::Mock.new
      good_sock.expect :read, "hi"
      good_sock.expect :hash, 123
      def good_sock.== o; o == self; end

      stash = TestStash.new nil

      stash << err_sock
      stash << good_sock

      stash.each {|s| s.read}
      good_sock.verify
    end

  end

end
