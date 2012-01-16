module ArResqueCounterCache

  module ActiveRecord

    ORIG_BT  = ::ActiveRecord::Associations::BelongsToAssociation
    ORIG_BTP = ::ActiveRecord::Associations::BelongsToPolymorphicAssociation

    module Associations

      module AsyncUpdateCounters
        def update_counters_with_async(record)
          # TODO make async?
          update_counters_without_async(record)
        end

        def self.included(base)
          base.class_eval do
            alias_method_chain :update_counters, :async
          end
        end
      end

      class AsyncBelongsToAssociation < ORIG_BT
        include AsyncUpdateCounters
      end

      class AsyncBelongsToPolymorphicAssociation < ORIG_BTP
        include AsyncUpdateCounters
      end
    end

    module AssociationReflectionTweaks
      def association_class_with_async
        if macro == :belongs_to && options[:async_counter_cache]
          if options[:polymorphic]
            Associations::AsyncBelongsToPolymorphicAssociation
          else
            Associations::AsyncBelongsToAssociation
          end
        else
          association_class_without_async
        end
      end

      def counter_cache_column_with_async
        if options[:async_counter_cache] == true
          "#{active_record.name.demodulize.underscore.pluralize}_count"
        elsif options[:async_counter_cache]
          options[:async_counter_cache].to_s
        else
          counter_cache_column_without_async
        end
      end

      def self.included(base)
        base.class_eval do
          alias_method_chain :association_class, :async
          alias_method_chain :counter_cache_column, :async
        end
      end
    end

    module AsyncBuilderBehavior
      def build_with_async
        reflection = build_without_async
        if options[:async_counter_cache] && options[:counter_cache]
          raise 'Do not mix `:async_counter_cache` and `:counter_cache`.'
        end
        if options[:async_counter_cache]
          add_async_counter_cache_callbacks(reflection)
        end
        reflection
      end

      def self.included(base)
        base.class_eval do
          alias_method_chain :build, :async
          self.valid_options += [:async_counter_cache]
        end
      end

      private

      def add_async_counter_cache_callbacks(reflection)
        cache_column = reflection.counter_cache_column
        name         = self.name

        method_name = "belongs_to_async_counter_cache_on_create_for_#{name}"
        model.redefine_method(method_name) do
          record = send(name)
          ArResqueCounterCache::IncrementCountersWorker.cache_and_enqueue(
            record.class.to_s,
            record.id,
            cache_column,
            :increment
          ) unless record.nil?
        end
        model.after_commit(method_name, :on => :create)

        method_name = "belongs_to_async_counter_cache_on_destroy_for_#{name}"
        model.redefine_method(method_name) do
          record = send(name)
          ArResqueCounterCache::IncrementCountersWorker.cache_and_enqueue(
            record.class.to_s,
            record.id,
            cache_column,
            :decrement
          ) unless record.nil?
        end
        model.after_commit(method_name, :on => :destroy)

        model.send(
          :module_eval,
          "#{reflection.class_name}.send(:attr_readonly,\"#{cache_column}\".intern) if defined?(#{reflection.class_name}) && #{reflection.class_name}.respond_to?(:attr_readonly)",
          __FILE__,
          __LINE__
        )
      end
    end
  end
end

ActiveRecord::Reflection::AssociationReflection.send(
  :include,
  ArResqueCounterCache::ActiveRecord::AssociationReflectionTweaks
)
ActiveRecord::Associations::Builder::BelongsTo.send(
  :include,
  ArResqueCounterCache::ActiveRecord::AsyncBuilderBehavior
)
