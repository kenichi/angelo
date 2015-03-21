# -*- encoding: utf-8 -*-
require File.expand_path('../lib/angelo/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors          = ["Kenichi Nakamura"]
  gem.email            = ["kenichi.nakamura@gmail.com"]
  gem.description      = gem.summary = "A Sinatra-like DSL for Reel"
  gem.homepage         = "https://github.com/kenichi/angelo"
  gem.files            = `git ls-files | grep -Ev '^example'`.split("\n")
  gem.test_files       = `git ls-files -- spec/*`.split("\n")
  gem.name             = "angelo"
  gem.require_paths    = ["lib"]
  gem.version          = Angelo::VERSION
  gem.license          = 'apache'
  gem.required_ruby_version = '>= 2.1.0'
  gem.add_runtime_dependency 'reel', '~>0.5'
  gem.add_runtime_dependency 'tilt', '~>2.0'
  gem.add_runtime_dependency 'tilt-preload'
  gem.add_runtime_dependency 'mustermann', '~>0.4'
  gem.add_runtime_dependency 'mime-types', '~>2.4'
end
