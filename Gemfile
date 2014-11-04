source 'https://rubygems.org'

gem 'reel', '~>0.5'
gem 'tilt', '~>2.0'
gem 'mime-types', '~>2.4'
gem 'websocket-driver', '~>0.3'

platform :ruby_20, :ruby_21 do
  gem 'mustermann', '~>0.3'
end

group :development do
  gem 'pry', '~>0.10'
  gem 'pry-nav', '~>0.2'
end

group :profile do
  platform :mri do
    gem 'ruby-prof', '~>0.15'
  end
end

group :test do
  gem 'httpclient', '~>2.5'
  gem 'minitest', '~>5.4'
end
