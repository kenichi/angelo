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

      def self.clear
        stashes.values.each &:clear
      end

    end

    after do
      TestStash.clear
    end

    def mock_good_sock
      good_sock = Minitest::Mock.new
      good_sock.expect :read, "hi"
      good_sock.expect :hash, 123
      def good_sock.== o
        o == self
      end
      def good_sock.eql? o
        self.object_id == o.object_id
      end
      good_sock
    end

    it 'does not skip live sockets when removing dead sockets' do
      stash = TestStash.new nil
      good_sock = mock_good_sock
      err_sock = ErrorSocket.new

      stash << err_sock
      stash << good_sock

      stash.each {|s| s.read}
      good_sock.verify
      stash.each {|s| err_sock.wont_equal s}
    end

    it 'removes sockets from contexts during all_each' do
      stash = TestStash.new nil
      good_sock = mock_good_sock
      err_sock = ErrorSocket.new

      stash[:foo] << err_sock
      stash[:bar] << good_sock

      stash.all_each {|s| s.read}
      good_sock.verify
      stash.all_each {|s| err_sock.wont_equal s}
    end

  end

end
