source 'https://rubygems.org'

gem 'reel'
gem 'tilt'
gem 'mime-types'
gem 'websocket-driver'

platform :rbx do
  gem 'rubysl-cgi'
  gem 'rubysl-erb'
  gem 'rubysl-prettyprint'
end

platform :ruby_20 do
  gem 'mustermann'
end

group :development do
  gem 'pry'
  gem 'pry-nav'
end

group :profile do
  platform :mri do
    gem 'ruby-prof'
  end
end

group :test do
  gem 'httpclient'
  gem 'rspec'
  gem 'rspec-pride'
end
