require 'active_record'
require 'ar-resque-counter-cache/increment_counters_worker'
require 'ar-resque-counter-cache/active_record'

ActiveRecord::Base.send(:include, ArAsyncCounterCache::ActiveRecord)
