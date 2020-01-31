# frozen_string_literal: true

module Doorkeeper
  class Config
    # Doorkeeper configuration option DSL
    module Option
      # Defines configuration option
      #
      # When you call option, it defines two methods. One method will take place
      # in the +Config+ class and the other method will take place in the
      # +Builder+ class.
      #
      # The +name+ parameter will set both builder method and config attribute.
      # If the +:as+ option is defined, the builder method will be the specified
      # option while the config attribute will be the +name+ parameter.
      #
      # If you want to introduce another level of config DSL you can
      # define +builder_class+ parameter.
      # Builder should take a block as the initializer parameter and respond to function +build+
      # that returns the value of the config attribute.
      #
      # ==== Options
      #
      # * [:+as+] Set the builder method that goes inside +configure+ block
      # * [+:default+] The default value in case no option was set
      # * [+:builder_class+] Configuration option builder class
      #
      # ==== Examples
      #
      #    option :name
      #    option :name, as: :set_name
      #    option :name, default: 'My Name'
      #    option :scopes builder_class: ScopesBuilder
      #
      def option(name, options = {})
        attribute = options[:as] || name
        attribute_builder = options[:builder_class]

        Builder.instance_eval do
          if method_defined?(name)
            Kernel.warn "[DOORKEEPER] Option #{name} already defined and will be overridden"
            remove_method name
          end

          if options[:deprecated]
            define_method name do |*_, &_|
              Kernel.warn "[DOORKEEPER] #{name} has been deprecated and will soon be removed"
            end
          else
            define_method name do |*args, &block|
              value = if attribute_builder
                        attribute_builder.new(&block).build
                      else
                        block || args.first
                      end

              @config.instance_variable_set(:"@#{attribute}", value)
            end
          end
        end

        define_method attribute do |*_args|
          if instance_variable_defined?(:"@#{attribute}")
            instance_variable_get(:"@#{attribute}")
          else
            options[:default]
          end
        end

        public attribute
      end
    end
  end
end
