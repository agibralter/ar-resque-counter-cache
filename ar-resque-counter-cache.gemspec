# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ar-resque-counter-cache/version"

Gem::Specification.new do |s|
  s.name        = "ar-resque-counter-cache"
  s.version     = ArAsyncCounterCache::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Aaron Gibralter"]
  s.email       = ["aaron.gibralter@gmail.com"]
  s.homepage    = "http://github.com/agibralter/ar-resque-counter-cache"
  s.summary     = %q{Increment ActiveRecord's counter cache column asynchronously using Resque (and resque-lock-timeout).}
  s.description = %q{Increment ActiveRecord's counter cache column asynchronously using Resque (and resque-lock-timeout).}

  s.rubyforge_project = "ar-resque-counter-cache"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "activerecord", "~> 3.0.0"
  s.add_dependency "resque", "~> 1.0"
  s.add_dependency "resque-lock-timeout", "~> 0.3.1"

  s.add_development_dependency "rspec", "~> 2.4.0"
  s.add_development_dependency "sqlite3-ruby", "~> 1.3.3"
end
