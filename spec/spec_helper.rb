spec_dir = File.expand_path(File.dirname(__FILE__))
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))

require 'rubygems'
require 'resque'
require 'ar-resque-counter-cache'
require 'rspec'
require 'models'

if !system("which redis-server")
  puts '', "** can't find `redis-server` in your path"
  abort ''
end

at_exit do
  Dir.chdir(spec_dir) do
    if (pid = `cat redis-test.pid`.strip) =~ /^\d+$/
      puts "Killing test redis server with pid #{pid}..."
      `rm -f dump.rdb`
      `rm -f redis-test.pid`
      Process.kill("KILL", pid.to_i)
    end
  end
end

puts "Starting redis for testing at localhost:9736..."
Dir.chdir(spec_dir) do
  `redis-server #{spec_dir}/redis-test.conf`
end

Resque.redis = '127.0.0.1:9736'

RSpec.configure do |config|
  config.before(:all) do
    ArAsyncCounterCache.resque_job_queue = :testing
  end
  config.before(:each) do
    ActiveRecord::Base.silence { CreateModelsForTest.migrate(:up) }
    Resque.redis.flushall
  end
  config.after(:each) do
    ActiveRecord::Base.silence { CreateModelsForTest.migrate(:down) }
  end
end
