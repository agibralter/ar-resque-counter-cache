require 'resque'
require 'resque-loner'

module ArResqueCounterCache

  # The default Resque queue is :counter_caches.
  def self.resque_job_queue=(queue)
    IncrementCountersWorker.class_eval do
      @queue = queue
    end
  end

  # If you don't want to use Resque's Redis connection to store the temporary
  # counter caches, you can set a different connection here.
  def self.redis=(redis)
    IncrementCountersWorker.class_eval do
      @redis = redis
    end
  end

  # ArResqueCounterCache will very quickly increment a counter cache in Redis,
  # which will then later be updated by a Resque job. Using require-loner, we
  # can ensure that only one job per payload is enqueued at a time.
  class IncrementCountersWorker

    include Resque::Plugins::UniqueJob
    @queue = :counter_caches
    @loner_ttl = 3600 # Don't hold lock for more than 1 hour...

    def self.cache_and_enqueue(parent_class, id, column, direction)
      parent_class = parent_class.to_s
      key = cache_key(parent_class, id, column)
      if direction == :increment
        redis.incr(key)
      elsif direction == :decrement
        redis.decr(key)
      else
        raise ArgumentError, "Must call ArResqueCounterCache::IncrementCountersWorker with :increment or :decrement"
      end
      ::Resque.enqueue(self, parent_class, id, column)
    end

    def self.redis
      @redis || ::Resque.redis
    end

    # args: (parent_class, id, column)
    def self.identifier(*args)
      args.join('-')
    end

    # args: (parent_class, id, column)
    def self.cache_key(*args)
      "ar-resque-counter-cache:#{identifier(*args)}"
    end

    def self.perform(parent_class, id, column)
      key = cache_key(parent_class, id, column)
      if (delta = redis.getset(key, 0).to_i) != 0
        begin
          parent_class = ::Resque.constantize(parent_class)
          parent_class.find(id)
          parent_class.update_counters(id, column => delta)
        rescue Exception => e
          # If anything happens, set back the counter cache.
          if delta > 0
            redis.incrby(key, delta)
          elsif delta < 0
            redis.decrby(key, -delta)
          end
          raise e
        end
      end
    end
  end
end
