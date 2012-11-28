# -*- encoding: utf-8 -*-
require File.expand_path('../lib/minimal_match/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["A.G. Russell Knives"]
  gem.email         = ["stephenp@agrussell.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "minimal_match"
  gem.require_paths = ["lib"]
  gem.version       = MinimalMatch::VERSION

  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'bundler'
  gem.add_development_dependency 'rspec'

end
