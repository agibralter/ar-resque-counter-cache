begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name        = "ar-resque-counter-cache"
    gemspec.summary     = "Increment ActiveRecord's counter cache column asynchronously using Resque (and resque-lock-timeout)."
    gemspec.description = "Increment ActiveRecord's counter cache column asynchronously using Resque (and resque-lock-timeout)."
    gemspec.email       = "aaron.gibralter@gmail.com"
    gemspec.homepage    = "http://github.com/agibralter/ar-resque-counter-cache"
    gemspec.authors     = ["Aaron Gibralter"]
    gemspec.add_dependency("activerecord", "~> 2.3.5")
    gemspec.add_dependency("resque", "~> 1.10.0")
    gemspec.add_dependency("resque-lock-timeout", "~> 0.2.1")
    gemspec.files.exclude("pkg")
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end
