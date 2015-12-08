$:.unshift File.expand_path '../../lib', __FILE__

if RUBY_ENGINE == "ruby" && ENV['TRAVIS'] != 'true'
  require 'simplecov'
  SimpleCov.coverage_dir File.join('test', 'coverage')
  SimpleCov.start
  SimpleCov.command_name 'minitest'
end

require 'bundler'
require 'celluloid/current'
Bundler.require :default, :development, :test
require 'minitest/pride'
require 'minitest/autorun'
require 'angelo'
require 'angelo/minitest/helpers'
Celluloid.logger.level = ::Logger::ERROR
include Angelo::Minitest::Helpers

TEST_APP_ROOT = File.expand_path '../test_app_root', __FILE__

CK = 'ANGELO_CONCURRENCY' # concurrency key
DC = 5                    # default concurrency
CONCURRENCY = ENV.key?(CK) ? ENV[CK].to_i : DC

# https://gist.github.com/tkareine/739662
#
class CountDownLatch
  attr_reader :count

  def initialize(to)
    @count = to.to_i
    raise ArgumentError, "cannot count down from negative integer" unless @count >= 0
    @lock = Mutex.new
    @condition = ConditionVariable.new
  end

  def count_down
    @lock.synchronize do
      @count -= 1 if @count > 0
      @condition.broadcast if @count == 0
    end
  end

  def wait
    @lock.synchronize do
      @condition.wait(@lock) while @count > 0
    end
  end

end

$reactor = Reactor.new
$pool = Array.new(CONCURRENCY){|n| Actor.new}

def obj
  {'foo' => 'bar', 'bar' => 123.4567890123456, 'bat' => true}
end

def obj_s
  obj.keys.reduce({}){|h,k| h[k] = obj[k].to_s; h}
end
