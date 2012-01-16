require 'resque'
require 'resque-lock-timeout'

module ArResqueCounterCache

  # The default Resque queue is :counter_caches.
  def self.resque_job_queue=(queue)
    IncrementCountersWorker.class_eval do
      @queue = queue
    end
  end

  # The default lock_timeout is 60 seconds.
  def self.resque_lock_timeout=(lock_timeout)
    IncrementCountersWorker.class_eval do
      @lock_timeout = lock_timeout
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
  # which will then later be updated by a Resque job. Using
  # require-lock-timeout, we can ensure that only one job per ___ is running
  # at a time.
  class IncrementCountersWorker

    extend ::Resque::Plugins::LockTimeout
    @queue = :counter_caches
    @lock_timeout = 60

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

    # Try again later if lock is in use.
    def self.lock_failed(*args)
      ::Resque.enqueue(self, *args)
    end

    # args: (parent_class, id, column)
    def self.cache_key(*args)
      "ar-resque-counter-cache:#{identifier(*args)}"
    end

    # The name of this method ensures that it runs within around_perform_lock.
    #
    # We've leveraged resque-lock-timeout to ensure that only one job is
    # running at a time. Now, this around filter essentially ensures that only
    # one job per parent-column can sit on the queue at once. Since the
    # cache_key entry in redis stores the most up-to-date delta for the
    # parent's counter cache, we don't have to actually perform the
    # Klass.update_counters for every increment/decrement. We can batch
    # process!
    def self.around_perform_lock1(*args)
      # Remove all other instances of this job (with the same args) from the
      # queue. Uses LREM (http://code.google.com/p/redis/wiki/LremCommand) which
      # takes the form: "LREM key count value" and if count == 0 removes all
      # instances of value from the list.
      redis_job_value = ::Resque.encode(:class => self.to_s, :args => args)
      ::Resque.redis.lrem("queue:#{@queue}", 0, redis_job_value)
      yield
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
