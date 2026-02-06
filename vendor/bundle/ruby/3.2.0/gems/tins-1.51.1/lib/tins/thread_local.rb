module Tins
  # Provides thread-local storage capabilities for classes and modules.
  # Thread-local variables are scoped to individual threads, allowing each
  # thread to maintain its own copy of the variable value.
  #
  # @example Basic usage with a class
  #   class MyClass
  #     extend Tins::ThreadLocal
  #
  #     thread_local :counter, 0
  #     thread_local :name, "default"
  #   end
  #
  #   # Each thread gets its own copy of the variables
  #   t1 = Thread.new { puts MyClass.new.counter }  # => 0
  #   t2 = Thread.new { puts MyClass.new.counter }  # => 0
  #   t1.join; t2.join
  #
  # @example Usage with default blocks
  #   class Config
  #     extend Tins::ThreadLocal
  #
  #     thread_local :database_url do
  #       ENV['DATABASE_URL'] || 'sqlite3://default.db'
  #     end
  #   end
  #
  # @example Instance-level thread local variables
  #   class MyClass
  #     include Tins::ThreadLocal
  #
  #     instance_thread_local :user_id, 0
  #   end
  module ThreadLocal
    # Cleanup lambda that removes thread-local data when objects are garbage
    # collected
    @@cleanup = lambda do |my_object_id|
      my_id = "__thread_local_#{my_object_id}__"
      for t in Thread.list
        t[my_id] = nil if t[my_id]
      end
    end

    # Define a thread local variable named +name+ in this module/class.
    # If the value +value+ is given, it is used to initialize the variable.
    #
    # @param name [Symbol, String] The name of the thread-local variable
    # @param default_value [Object] Optional default value for the variable
    # @yield [void] Optional block that returns the default value
    # @return [self]
    # @raise [TypeError] If receiver is not a Module
    # @raise [ArgumentError] If both default_value and default block are provided
    #
    # @example With static default value
    #   thread_local :counter, 0
    #
    # @example With dynamic default value via block
    #   thread_local :timestamp do
    #     Time.now
    #   end
    def thread_local(name, default_value = nil, &default)
      is_a?(Module) or raise TypeError, "receiver has to be a Module"

      default_value && default and raise ArgumentError,
        "require either default_value or default block"

      if default_value
        default = -> * { default_value }
      end

      name = name.to_s
      my_id = "__thread_local_#{__id__}__"

      ObjectSpace.define_finalizer(self, @@cleanup)

      define_method(name) do
        values = Thread.current[my_id] ||= {}
        if default && !values.key?(name)
          values[name] = default.call
        end
        values[name]
      end

      define_method("#{name}=") do |value|
        Thread.current[my_id] ||= {}
        Thread.current[my_id][name] = value
      end

      self
    end

    # Define a thread local variable for the current instance with name +name+.
    # If the value +value+ is given, it is used to initialize the variable.
    #
    # @param name [Symbol, String] The name of the thread-local variable
    # @param default_value [Object] Optional default value for the variable
    # @yield [void] Optional block that returns the default value
    # @return [self]
    #
    # @example Basic usage
    #   class MyClass
    #     include Tins::ThreadLocal
    #
    #     instance_thread_local :user_id, 0
    #   end
    def instance_thread_local(name, default_value = nil, &default)
      class << self
        extend Tins::ThreadLocal
        self
      end.thread_local name, default_value, &default

      self
    end
  end
end
