ar-resque-counter-cache (formerly ar-async-counter-cache)
---------------------------------------------------------

This gem allows you to update ActiveRecord (2.3.x) counter cache columns
asynchronously using Resque (http://github.com/defunkt/resque). You may want to
do this in situations where you want really speedy inserts and have models that
"belong_to" many different parents; that is, you want the request making the
INSERT to return before waiting for the many UPDATE...SET counter cache SQL
queries to finish. You may also want to use this gem to avoid "Mysql::Error:
Lock wait timeout exceeded" issues: if you have a lot of children being created
at a time for a single parent row, MySQL can run into lock timeouts while
waiting for parent row to update its counter cache over and over. A while ago,
I remember
[seeing](http://robots.thoughtbot.com/post/159805685/tuning-the-toad) that
Thoughtbot was having a similar issue in its Hoptoad service...

How does ar-resque-counter-cache address these issues? It uses Redis as a
temporary counter cache and Resque to actually update the counter cache column
sometime in the future. For example, let's say a single Post gets 1000 comments
very quickly. This will set a key in Redis indicating that there is a delta of
+1000 for that Post's comments_count column. Previously (in versions 3.0.2 and
below), it would also queue 1000 Resque jobs. This is where resque-lock-timeout
came in. Only one of those jobs will be allowed to run at a time. Once a job
acquires the lock it removes all other instances of that job from the queue
(see IncrementCountersWorker.around\_perform\_lock1) using Redis's lrem
command. Unfortunately we ran into some giant Redis cpu overload with lrems
during traffic spikes and decided to switch to the simpler resque-loner gem.
This gem instead uses a key to determine whether or not to enqueue a given job
in the first place.

You use it like such:

    class User < ActiveRecord::Base
      has_many :comments
      has_many :posts
    end
    
    class Post < ActiveRecord::Base
      belongs_to :user, :async_counter_cache => true
      has_many :comments
    end
    
    class Comment < ActiveRecord::Base
      belongs_to :user, :async_counter_cache => true
      belongs_to :post, :async_counter_cache => "count_of_comments"
    end

Notice, you may specify the name of the counter cache column just as you can
with the normal belongs_to `:counter_cache` option. You also may not use both
the `:async_counter_cache` and `:counter_cache` options in the same belongs_to
call.

All you should need to do is require this gem in your project that uses
ActiveRecord and you should be good to go;

e.g. In your Gemfile:

    gem 'ar-resque-counter-cache', 'x.x.x'

and then in RAILS_ROOT/config/environment.rb somewhere:

    require 'ar-resque-counter-cache'

By default, the Resque job is placed on the `:counter_caches` queue:

    @queue = :counter_caches

However, you can change this:

in RAILS_ROOT/config/environment.rb somewhere:

    ArAsyncCounterCache.resque_job_queue = :low_priority

`ArAsyncCounterCache::IncrementCountersWorker.cache_and_enqueue` can also be
used to increment/decrement arbitrary counter cache columns (outside of
belongs_to associations):

    ArAsyncCounterCache::IncrementCountersWorker.cache_and_enqueue(klass, id, column, direction)

Where:

 * `klass` is the Class of the ActiveRecord object
 * `id` is the id of the object
 * `column` is the counter cache column
 * `direction` is either `:increment` or `:decrement`
