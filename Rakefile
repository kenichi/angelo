require 'rake/testtask'

Rake::TestTask.new do |t|
  t.pattern = ENV['TEST_PATTERN'] || "spec/**/*_spec.rb"
end

task :default => :test
