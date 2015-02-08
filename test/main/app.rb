# This file is run by main_test.rb.  It starts a separate server
# process that main_spec.rb queries to make sure things get set up and
# work correctly with require "angelo/main" which we don't want to
# require in the test process because it wants to take over: parse
# args, add methods to main, and run a server.  So we isolate it in
# its own process here.

require "rubygems"
require "bundler/setup"

$:.unshift File.expand_path "../../../lib", __FILE__
require "angelo/main"

# Use top-level DSL to make sure it works.  And the server should
# auto-run at exit.

helpers do
  def help_me
    "help me!"
  end
end

content_type :html

get "/app_file" do
  self.class.app_file
end

get "/mainonly" do
  begin
    Object.new.send(:get, "/spud") {}
    "false"
  rescue NameError
    "true"
  end
end

get "/help" do
  help_me
end
