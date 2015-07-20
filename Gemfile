source 'https://rubygems.org'

gem 'reel', github: 'celluloid/reel', branch: '0.6.0-milestone', submodules: true
gem 'tilt', '~>2.0'
gem 'mime-types', '~>2.4'
gem 'websocket-driver', '~>0.5'
gem 'mustermann', '~>0.4'

group :development do
  gem 'pry', '~>0.10'
end

group :profile do
  platform :mri do
    gem 'ruby-prof', '~>0.15'
  end
end

group :test do
  gem 'httpclient', '~>2.5'
  gem 'minitest', '~>5.4'

  platform :mri do
    gem 'simplecov', '~>0.10.0'
  end
end
