require 'active_record'
require 'ar_resque_counter_cache/increment_counters_worker'
require 'ar_resque_counter_cache/active_record'

ActiveRecord::Base.send(:include, ArAsyncCounterCache::ActiveRecord)
