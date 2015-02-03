# These tests start a real server and talk to it over TCP so we can
# isolate the effects of require "angelo/main" in a separate process
# but still test them.
#
# See test/main/app.rb for the code of the app we test against.

require_relative '../spec_helper'

class MainSpec < Minitest::Spec

  # Info for starting the server.

  app_file = File.expand_path("../app.rb", __FILE__)
  address = "127.0.0.1"
  port = 14410

  server_command = "#{RbConfig.ruby} #{app_file} -o #{address} -p #{port}"

  # Start the server.

  pid = spawn server_command, out: "/dev/null", err: "/dev/null"

  # Prepare to shut it down.

  MiniTest.after_run do
    begin
      Process.kill("KILL", pid)
    rescue Errno::ESRCH
    end
  end

  # Client for talking to the server.

  client = HTTPClient.new
  client.connect_timeout = 1
  client.send_timeout = 1
  client.receive_timeout = 1

  # Use define method so client_get's body is a closure that captures
  # the lovely variables we just set up.  Nevermind all the hoops we
  # have to jump through to do that.  Define this on the class because
  # we're going to need it in a bit to check that the server is alive.

  class << self; self; end.class_eval do
    define_method :client_get do |url|
      client.get("http://#{address}:#{port}#{url}").body
    end
  end

  def client_get(url)
    self.class.client_get(url)
  end

  # Wait for the server to start up.  If it doesn't start, the
  # cleanest thing to do seems ot be to let the tests run anyway and
  # fail to connect.

  def self.wait_for_server(timeout)
    started = Time.now
    while !(alive = alive?) && Time.now - started < timeout
      sleep 0.1
    end
    alive
  end

  def self.alive?
    # This will 404 but that's good enough.
    3.times { client_get("/ping") }
    true
  rescue Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError, SystemCallError
    # No doubt that's not an exhaustive list of exceptions we should
    # rescue.
    false
  end

  if !self.wait_for_server(2)
    # Write this out after the tests finish, where it's likely to be seen.
    MiniTest.after_run do
      STDERR.puts
      STDERR.puts "The server for main_spec.rb failed to start."
      STDERR.puts "Try running it manually for debugging like this:"
      STDERR.puts "  #{server_command}"
      STDERR.puts
    end
  end

  describe 'require "angelo/main"' do
    it "sets app_file to the file being run" do
      client_get("/app_file").must_equal app_file
    end

    it "only extends main" do
      client_get("/mainonly").must_equal "true"
    end

    it "makes helpers accessible" do
      client_get("/help").must_equal "help me!"
    end
  end

end
