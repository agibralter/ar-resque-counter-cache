module ArAsyncCounterCache

  module ActiveRecord

    def update_async_counters(dir, *association_ids)
      association_ids.each do |association_id|
        reflection = self.class.reflect_on_association(association_id)
        parent_class = reflection.klass
        column = self.class.async_counter_types[association_id]
        if parent_id = send(reflection.primary_key_name)
          ArAsyncCounterCache::IncrementCountersWorker.cache_and_enqueue(parent_class, parent_id, column, dir)
        end
      end
    end

    module ClassMethods

      def belongs_to(association_id, options={})
        column = async_counter_cache_column(options.delete(:async_counter_cache))
        raise "Please don't use both async_counter_cache and counter_cache." if column && options[:counter_cache]
        super(association_id, options)
        if column
          # Store the async_counter_cache column for the update_async_counters
          # helper method.
          self.async_counter_types[association_id] = column
          # Fetch the reflection.
          reflection = self.reflect_on_association(association_id)
          parent_class = reflection.klass
          # Let's make the column read-only like the normal belongs_to
          # counter_cache.
          parent_class.send(:attr_readonly, column.to_sym) if defined?(parent_class) && parent_class.respond_to?(:attr_readonly)
          parent_id_column = reflection.primary_key_name
          add_callbacks(parent_class.to_s, parent_id_column, column)
        end
      end

      def async_counter_types
        @async_counter_types ||= {}
      end

      private

      def add_callbacks(parent_class, parent_id_column, column)
        base_method_name = "async_counter_cache_#{parent_class}_#{column}"
        # Define after_create callback method.
        method_name = "#{base_method_name}_after_create".to_sym
        define_method(method_name) do
          if parent_id = send(parent_id_column)
            ArAsyncCounterCache::IncrementCountersWorker.cache_and_enqueue(parent_class, parent_id, column, :increment)
          end
        end
        after_create(method_name)
        # Define after_destroy callback method.
        method_name = "#{base_method_name}_after_destroy".to_sym
        define_method(method_name) do
          if parent_id = send(parent_id_column)
            ArAsyncCounterCache::IncrementCountersWorker.cache_and_enqueue(parent_class, parent_id, column, :decrement)
          end
        end
        after_destroy(method_name)
      end

      def async_counter_cache_column(opt)
        opt === true ? "#{self.table_name}_count" : opt
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
  end
end
