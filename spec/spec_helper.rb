spec_dir = File.expand_path(File.dirname(__FILE__))
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))

require 'rubygems'
# Ensure resque for tests.
require 'resque'
require 'ar-resque-counter-cache'
require 'spec'
require 'models'

cwd = Dir.getwd
Dir.chdir(spec_dir)

if !system("which redis-server")
  puts '', "** can't find `redis-server` in your path"
  abort ''
end

at_exit do
  if (pid = `cat redis-test.pid`.strip) =~ /^\d+$/
    puts "Killing test redis server with pid #{pid}..."
    `rm -f dump.rdb`
    `rm -f redis-test.pid`
    Process.kill("KILL", pid.to_i)
    Dir.chdir(cwd)
  end
end

puts "Starting redis for testing at localhost:9736..."
`redis-server #{spec_dir}/redis-test.conf`
Resque.redis = '127.0.0.1:9736'

Spec::Runner.configure do |config|
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
