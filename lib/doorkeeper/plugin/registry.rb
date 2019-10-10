# frozen_string_literal: true

module Doorkeeper
  module Plugin
    # Doorkeeper plugins registry.
    # Stores all the registered plugins and acts as a manager that can
    # invoke plugins based on namespace they used for.
    #
    class Registry
      class << self
        NAMESPACE_REGEX = /^[a-z][\w\.-]+[a-z]$/i.freeze

        # Registered Doorkeeper plugins
        #
        # @return [Hash] plugins mapping
        #
        # @example
        #   {
        #     "access_token.create": [
        #       { class: Doorkeeper::Plugins::EncryptSecrets, options: { key: ENV["key"] } }
        #     ],
        #     "access_token.refresh": [
        #       { class: Doorkeeper::Plugins::ClearRefreshTokens, options: {} }
        #     ],
        #   }
        def plugins
          @plugins ||= {}
        end

        # Safely registers plugin
        #
        # @param klass [Class]
        #   plugin class
        #
        # @param namespace [String, #to_s]
        #   namespace where plugin would be used
        #
        # @param options [Hash]
        #   plugin options
        #
        def register(klass, namespace:, **options)
          assert_finalized!

          namespace = namespace.to_s

          unless namespace.match?(NAMESPACE_REGEX)
            raise ArgumentError, "namespace must contain only letters, digits and underscore"
          end
          if exist?(klass, namespace)
            raise ArgumentError, "'#{klass}' already registered for #{namespace}"
          end

          if options.key?(:after) || options.key?(:before)
            register_with_order(klass, namespace, options)
          else
            plugins[namespace] ||= []
            plugins[namespace] << build(klass, options)
          end

          self
        end

        # Removes plugin from the registry.
        #
        # @param klass [Class]
        #   plugin class
        #
        # @param namespace [String, #to_s]
        #   namespace where plugin would be used
        #
        def remove(klass, namespace)
          assert_finalized!

          namespaced_plugins(namespace).delete_if { |plugin| plugin[:class] == klass }
        end

        # Removes all the plugins from the registry
        # (or just namespace if specified).
        #
        # @param namespace [String, #to_s]
        #   namespace where plugin would be used
        #
        def clear(namespace = nil)
          assert_finalized!

          if namespace
            namespaced_plugins(namespace).clear
          else
            plugins.clear
          end
        end

        alias clean clear

        # Invokes all the plugins for the specific namespace to run.
        #
        # @param namespace [String, #to_s]
        #   namespace where plugin would be used
        #
        # @param context [Hash]
        #   context for the plugin that stores useful objects
        #   for plugin purposes
        #
        def run(namespace, **context)
          namespaced_plugins(namespace).each do |plugin|
            run_plugin(plugin, **context)
          end

          self
        end

        def finalize
          plugins.each_value do |entry|
            entry.each(&:freeze)
            entry.freeze
          end

          plugins.freeze

          self
        end

        alias run_for run

        protected

        def namespaced_plugins(namespace)
          plugins[namespace.to_s] || []
        end

        def exist?(klass, namespace)
          !namespaced_plugins(namespace).detect { |plugin| plugin[:class] == klass }.nil?
        end

        def build(klass, options)
          raise ArgumentError, "'#{klass}' must be a class!" unless klass.is_a?(Class)
          raise ArgumentError, "#{klass} must respond to #run method!" unless klass.method_defined?(:run)

          internal_options = (options || {}).except(:options)

          { class: klass, options: options[:options] || {}, internal_options: internal_options }
        end

        def insert(plugin, namespace, index)
          raise ArgumentError, "plugin must be a Hash!" unless plugin.is_a?(Hash)
          raise ArgumentError, "unknown namespace '#{namespace}'" unless plugins.key?(namespace.to_s)

          namespaced_plugins(namespace).insert(index, plugin)
        end

        def register_with_order(klass, namespace, options)
          after = options.delete(:after)
          before = options.delete(:before)

          plugin_class = after || before

          index = index_for(plugin_class, namespace)
          raise ArgumentError, "#{plugin_class} could not be found for #{namespace}" if index.nil?

          plugin = build(klass, options)

          if after
            insert(plugin, namespace, index + 1)
          else
            insert(plugin, namespace, index.zero? ? 0 : index - 1)
          end
        end

        def index_for(klass, namespace)
          namespaced_plugins(namespace).index { |plugin| plugin[:class] == klass }
        end

        def run_plugin(plugin, **context)
          plugin[:class].new(plugin[:options]).run(**context)
        rescue StandardError => e
          raise e unless plugin.dig(:internal_options, :shallow_exceptions)
        end

        def assert_finalized!
          raise FrozenError, "plugins already finalized!" if plugins.frozen?
        end
      end
    end
  end
end
