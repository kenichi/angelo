# -*- encoding: utf-8 -*-
require File.expand_path('../lib/angelo/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Kenichi Nakamura"]
  gem.email         = ["kenichi.nakamura@gmail.com"]
  gem.description   = gem.summary = "A Sinatra-esque DSL for Reel"
  gem.homepage      = "https://github.com/kenichi/angelo"
  gem.files         = `git ls-files | grep -Ev '^(myapp|examples)'`.split("\n")
  gem.test_files    = `git ls-files -- test/*`.split("\n")
  gem.name          = "angelo"
  gem.require_paths = ["lib"]
  gem.version       = Angelo::VERSION
  gem.license       = 'apache'
  gem.add_dependency 'reel'
end
