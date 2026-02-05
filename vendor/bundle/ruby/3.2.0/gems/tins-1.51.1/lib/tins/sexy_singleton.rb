require 'tins/string_version'
require 'singleton'

module Tins
  # Enhanced singleton implementation that forwards method calls to the
  # instance.
  #
  # This module provides a "sexy" singleton implementation that extends the
  # standard Ruby singleton pattern by making the singleton class itself
  # respond to methods defined on the instance. This allows for more intuitive
  # usage where you can call singleton methods directly on the class without
  # needing to access the instance explicitly.
  #
  # @example Basic usage
  #   class MySingleton
  #     include Tins::SexySingleton
  #
  #     def hello
  #       "Hello World"
  #     end
  #   end
  #
  #   # You can now call methods directly on the class
  #   MySingleton.hello  # => "Hello World"
  SexySingleton = Singleton.dup

  SexySingleton.singleton_class.class_eval do
    alias __old_singleton_included__ included

    # Extends the standard singleton inclusion to forward method calls from the
    # singleton class to the instance.
    #
    # This method is automatically called when including {SexySingleton} in a
    # class. It sets up the singleton class to delegate method calls to the
    # instance, making it possible to call singleton methods directly on the
    # class.
    #
    # @param klass [Class] The class that includes this module
    def included(klass)
      __old_singleton_included__(klass)
      klass.singleton_class.class_eval do
        if Object.method_defined?(:respond_to_missing?)
          def  respond_to_missing?(name, *args, **kwargs)
            instance.respond_to?(name) || super
          end
        else
          def respond_to?(name, *args, **kwargs)
            instance.respond_to?(name) || super
          end
        end

        def method_missing(name, *args, **kwargs, &block)
          if instance.respond_to?(name)
            instance.__send__(name, *args, **kwargs, &block)
          else
            super
          end
        end
      end
      super
    end
  end
end
