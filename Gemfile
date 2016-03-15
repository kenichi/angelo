source 'https://rubygems.org'

gem 'reel', '~>0.6.1'
gemspec

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
    gem 'simplecov', '~>0.11'
  end
end
