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

  s.add_dependency "activerecord", "~> 2.3.5"
  s.add_dependency "resque", "~> 1.10"
  s.add_dependency "resque-lock-timeout", "~> 0.2.1"
  s.add_dependency "after_commit", "~> 1.0.6"

  s.add_development_dependency "rspec", "~> 1.3.0"
  s.add_development_dependency "sqlite3-ruby", "~> 1.3.3"
  s.add_development_dependency "SystemTimer", "~> 1.2.2"
end
