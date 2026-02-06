require 'thread'
require 'sync'

require 'tins/thread_local'

module Tins
  # This module contains some handy methods to deal with eigenclasses. Those
  # are also known as virtual classes, singleton classes, metaclasses, plus all
  # the other names Matz doesn't like enough to actually accept one of the
  # names.
  #
  # The module can be included into other modules/classes to make the methods available.
  #
  # @example Using eigenclass alias
  #   class MyClass
  #     include Tins::Eigenclass
  #   end
  #
  #   puts MyClass.eigenclass  # => MyClass singleton class
  module Eigenclass
    # Returns the eigenclass of this object.
    #
    # @return [Class] The eigenclass (singleton class) of the receiver
    alias eigenclass singleton_class

    # Evaluates the _block_ in context of the eigenclass of this object.
    #
    # This method allows you to define singleton methods or access singleton
    # class methods directly on an object.
    #
    # @yield [] The block to evaluate in the eigenclass context
    # @yieldparam obj [Object] The object whose eigenclass is being evaluated
    # @return [Object] The result of the last expression in the block
    # @example Defining class methods using attr_accessor on a class
    #   class MyClass
    #     include Tins::Eigenclass
    #   end
    #
    #   MyClass.eigenclass_eval { attr_accessor :foo }
    #   MyClass.foo = "bar"
    #   MyClass.foo  # => "bar"
    def eigenclass_eval(&block)
      eigenclass.instance_eval(&block)
    end


    # Evaluates the _block_ in context of the eigenclass's class context.
    #
    # This method allows you to define class methods on the eigenclass itself,
    # which is different from +eigenclass_eval+ that defines singleton methods
    # on the object instance.
    #
    # @yield [] The block to evaluate in the eigenclass's class context
    # @return [Object] The result of the last expression in the block
    #
    # @example Defining class methods on eigenclass
    #   class MyClass
    #     include Tins::Eigenclass
    #   end
    #
    #   obj = MyClass.new
    #   obj.eigenclass_class_eval { def foo; "bar"; end }
    #   obj.foo  # => "bar"
    def eigenclass_class_eval(&block)
      eigenclass.class_eval(&block)
    end
  end

  # This module provides convenient helpers for defining class methods and
  # attributes on classes themselves.
  #
  # @example Using ClassMethod module to define class methods dynamically
  #   class MyClass
  #     include Tins::ClassMethod
  #   end
  #
  #   # Define class methods using the ClassMethod helpers
  #   MyClass.class_attr_accessor :foo
  #   MyClass.foo = "bar"
  #   MyClass.foo  # => "bar"
  #
  #   MyClass.class_define_method(:baz) { "qux" }
  #   MyClass.baz  # => "qux"
  module ClassMethod
    include Eigenclass

    # Define a class method named _name_ using _block_.
    #
    # @param name [Symbol] The name of the method to define
    # @yield [Object] The block that defines the method's behavior
    # @return [void]
    def class_define_method(name, &block)
      eigenclass_eval { define_method(name, &block) }
    end

    # Define reader and writer attribute methods for all <i>*ids</i>.
    #
    # @param ids [Array<Symbol>] The names of the attributes to define
    # @return [void]
    def class_attr_accessor(*ids)
      eigenclass_eval { attr_accessor(*ids) }
    end

    # Alias for {class_attr_accessor}
    #
    # @see class_attr_accessor
    alias class_attr class_attr_accessor

    # Define reader attribute methods for all <i>*ids</i>.
    #
    # @param ids [Array<Symbol>] The names of the attributes to define
    # @return [void]
    def class_attr_reader(*ids)
      eigenclass_eval { attr_reader(*ids) }
    end

    # Define writer attribute methods for all <i>*ids</i>.
    #
    # @param ids [Array<Symbol>] The names of the attributes to define
    # @return [void]
    def class_attr_writer(*ids)
      eigenclass_eval { attr_writer(*ids) }
    end
  end

  # Provides thread-safe global variable functionality for modules and classes.
  #
  # This module enables the definition of thread-global variables that maintain
  # their state per thread within a given module or class scope. These variables
  # are initialized lazily and provide thread safety through mutex synchronization.
  #
  # @example Basic usage with module-level thread globals
  #   class MyClass
  #     extend Tins::ThreadGlobal
  #
  #     thread_global :counter, 0
  #   end
  #
  #   mc = MyClass.new
  #   mc2 = MyClass.new
  #   mc.counter = 5
  #   puts mc.counter  # => 5
  #   puts mc2.counter # => 5
  #   mc2.counter = 6
  #   puts mc.counter  # => 6
  #
  # @example Usage with instance-level thread globals
  #   require 'securerandom'
  #
  #   class MyClass
  #     include Tins::ThreadGlobal
  #
  #     def initialize
  #       instance_thread_global :session_id, SecureRandom.uuid
  #     end
  #   end
  #
  #   obj = MyClass.new
  #   puts obj.session_id # => unique UUID per instance
  module ThreadGlobal
    # Define a thread global variable named _name_ in this module/class. If the
    # value _value_ is given, it is used to initialize the variable.
    #
    # Thread global variables maintain their state per thread within the scope
    # of the module or class where they are defined. The initialization is lazy,
    # meaning the default value or block is only executed when first accessed.
    #
    # @param name [Symbol, String] The name of the thread global variable to define
    # @param default_value [Object] The default value for the variable (optional)
    # @yield [Object] A block that returns the default value for lazy initialization
    # @yieldparam args [Array] Arguments passed to the default block
    # @return [self] Returns self to allow method chaining
    # @raise [TypeError] If the receiver is not a Module
    # @raise [ArgumentError] If both default_value and default block are provided
    # @example Define with default value
    #   thread_global :counter, 0
    # @example Define with lazy initialization block
    #   thread_global :config do
    #     { timeout: 30, retries: 3 }
    #   end
    def thread_global(name, default_value = nil, &default)
      is_a?(Module) or raise TypeError, "receiver has to be a Module"

      default_value && default and raise ArgumentError,
        "require either default_falue or default block"

      if default_value
        default = -> * { default_value }
      end

      name = name.to_s
      var_name = "@__#{name}_#{__id__.abs}__"

      lock = Mutex.new
      modul = self

      define_method(name) do
        lock.synchronize {
          if default && !modul.instance_variable_defined?(var_name)
            modul.instance_variable_set var_name, default.call
          end
          modul.instance_variable_get var_name
        }
      end

      define_method(name + "=") do |value|
        lock.synchronize { modul.instance_variable_set var_name, value }
      end

      self
    end

    # Define a thread global variable for the current instance with name
    # _name_. If the value _value_ is given, it is used to initialize the
    # variable.
    #
    # This method creates thread-global variables at the instance level by
    # extending the singleton class of the current object. It's useful when
    # you need per-instance global state that's still thread-safe.
    #
    # @param name [Symbol, String] The name of the thread global variable to define
    # @param value [Object] The initial value for the variable (optional)
    # @return [self] Returns self to allow method chaining
    # @example Create instance thread global
    #   class MyClass
    #     include Tins::ThreadGlobal
    #
    #     def initialize
    #       instance_thread_global :session_id, SecureRandom.uuid
    #     end
    #   end
    def instance_thread_global(name, value = nil)
      sc = class << self
        extend Tins::ThreadGlobal
        self
      end
      sc.thread_global name, value
      self
    end
  end

  # Provides dynamic code interpretation capabilities for evaluating string-based
  # code within the context of an object instance.
  #
  # This module enables the execution of Ruby code snippets as if they were
  # blocks, maintaining access to the current binding and instance variables.
  #
  # @example Basic usage with automatic binding
  #   class A
  #     include Tins::Interpreter
  #     def c
  #       3
  #     end
  #   end
  #
  #   A.new.interpret('|a,b| a + b + c', 1, 2) # => 6
  #
  # @example Usage with explicit binding
  #   class A
  #     include Tins::Interpreter
  #     def c
  #       3
  #     end
  #     def foo
  #       b = 2
  #       interpret_with_binding('|a| a + b + c', binding, 1) # => 6
  #     end
  #   end
  #
  #   A.new.foo # => 6
  module Interpreter
    # Interpret the string _source_ as a body of a block, while passing
    # <i>*args</i> into the block.
    #
    # This method automatically creates a binding from the current context,
    # making all instance variables and methods available to the interpreted code.
    #
    # @param source [String, IO] The Ruby code to evaluate as a block body
    # @param args [Array] Arguments to pass to the interpreted block
    # @return [Object] The result of evaluating the interpreted code
    # @see #interpret_with_binding
    def interpret(source, *args)
      interpret_with_binding(source, binding, *args)
    end

    # Interpret the string _source_ as a body of a block, while passing
    # <i>*args</i> into the block and using _my_binding_ for evaluation.
    #
    # This method allows explicit control over the binding context, enabling
    # access to specific local variables from a particular scope.
    #
    # @param source [String, IO] The Ruby code to evaluate as a block body
    # @param my_binding [Binding] The binding object to use for evaluation
    # @param args [Array] Arguments to pass to the interpreted block
    # @return [Object] The result of evaluating the interpreted code
    # @see #interpret
    def interpret_with_binding(source, my_binding, *args)
      path = '(interpret)'
      if source.respond_to? :to_io
        path = source.path if source.respond_to? :path
        source = source.to_io.read
      end
      block = lambda { |*a| eval("lambda { #{source} }", my_binding, path).call(*a) }
      instance_exec(*args, &block)
    end
  end

  # A module that provides method-based DSL constant creation functionality.
  # These constants are particularly useful for creating DSLs and configuration
  # systems where symbolic names improve readability and maintainability.
  #
  # @example Basic constant creation
  #   class MyClass
  #     extend Tins::Constant
  #
  #     constant :yes, true
  #     constant :no, false
  #   end
  #
  #   MyClass.instance_eval do
  #     yes    # => true
  #     no     # => false
  #   end
  #
  # @see DSLAccessor#dsl_accessor For mutable accessor alternatives and a more
  #   advanced example.
  module Constant
    # Creates a method-based constant named _name_ that returns _value_.
    #
    # This method defines a method with the given name that always returns the
    # specified value. The value is attempted to be frozen for immutability,
    # though this will fail gracefully if freezing isn't possible for the value.
    #
    # @param name [Symbol] The name of the constant method to define
    # @param value [Object] The value the constant should return (defaults to name)
    # @return [void]
    def constant(name, value = name)
      value = value.freeze rescue value
      define_method(name) { value }
    end
  end

  # The DSLAccessor module contains some methods, that can be used to make
  # simple accessors for a DSL.
  #
  #
  #  class CoffeeMaker
  #    extend Tins::Constant
  #
  #    constant :on
  #    constant :off
  #
  #    extend Tins::DSLAccessor
  #
  #    dsl_accessor(:state) { off } # Note: the off constant from above is used
  #
  #    dsl_accessor :allowed_states, :on, :off
  #
  #    def process
  #      allowed_states.include?(state) or fail "Explode!!!"
  #      if state == on
  #        puts "Make coffee."
  #      else
  #        puts "Idle..."
  #      end
  #    end
  #  end
  #
  #  cm = CoffeeMaker.new
  #  cm.instance_eval do
  #    state      # => :off
  #    state on
  #    state      # => :on
  #    process    # => outputs "Make coffee."
  #  end
  #
  # Note that Tins::SymbolMaker is an alternative for Tins::Constant in
  # this example. On the other hand SymbolMaker can make debugging more
  # difficult.
  module DSLAccessor
    # This method creates a dsl accessor named _name_. If nothing else is given
    # as argument it defaults to nil. If <i>*default</i> is given as a single
    # value it is used as a default value, if more than one value is given the
    # _default_ array is used as the default value. If no default value but a
    # block _block_ is given as an argument, the block is executed everytime
    # the accessor is read <b>in the context of the current instance</b>.
    #
    # After setting up the accessor, the set or default value can be retrieved
    # by calling the method +name+. To set a value one can call <code>name
    # :foo</code> to set the attribute value to <code>:foo</code> or
    # <code>name(:foo, :bar)</code> to set it to <code>[ :foo, :bar ]</code>.
    def dsl_accessor(name, *default, &block)
      variable = "@#{name}"
      define_method(name) do |*args|
        if args.empty?
          result =
            if instance_variable_defined?(variable)
              instance_variable_get(variable)
            end
          if result.nil?
            result = if default.empty?
              block && instance_eval(&block)
            elsif default.size == 1
              default.first
            else
              default
            end
            instance_variable_set(variable, result)
            result
          else
            result
          end
        else
          instance_variable_set(variable, args.size == 1 ? args.first : args)
        end
      end
    end

    # The dsl_lazy_accessor method defines a lazy-loaded accessor method with
    # a default block.
    #
    # This method creates a dynamic accessor that initializes its value
    # lazily when first accessed. It stores the default value as a block in
    # an instance variable and evaluates it on first access. If a block is
    # passed to the accessor, it sets the instance variable to that block for
    # future use.
    #
    # @param name [ Object ] the name of the accessor method to define
    # @yield [ default ] optional block that provides the default value for initialization
    #
    # @return [ Symbol ] returns name of the defined method.
    def dsl_lazy_accessor(name, &default)
      variable = "@#{name}"
      define_method(name) do |*args, &block|
        if !block && args.empty?
          if instance_variable_defined?(variable)
            instance_eval(&instance_variable_get(variable))
          elsif default
            instance_eval(&default)
          end
        elsif block
          instance_variable_set(variable, block)
        else
          raise ArgumentError, '&block argument is required'
        end
      end
    end

    # This method creates a dsl reader accessor, that behaves exactly like a
    # #dsl_accessor but can only be read not set.
    def dsl_reader(name, *default, &block)
      variable = "@#{name}"
      define_method(name) do |*args|
        if args.empty?
          result =
            if instance_variable_defined?(variable)
              instance_variable_get(variable)
            end
          if result.nil?
            if default.empty?
              block && instance_eval(&block)
            elsif default.size == 1
              default.first
            else
              default
            end
          else
            result
          end
        else
          raise ArgumentError, "wrong number of arguments (#{args.size} for 0)"
        end
      end
    end
  end

  # A module that provides method missing handler for symbolic method calls.
  #
  # This module enables dynamic method resolution by converting missing method
  # calls into symbols. When a method is called that doesn't exist, instead of
  # raising NoMethodError, the method name is returned as a symbol. This is
  # particularly useful for creating DSLs, configuration systems, and symbolic
  # interfaces.
  #
  # @example Combined with DSLAccessor for powerful configuration
  #   class CoffeeMaker
  #     include Tins::SymbolMaker
  #     extend Tins::DSLAccessor
  #
  #     dsl_accessor(:state) { :off }
  #     dsl_accessor :allowed_states, :on, :off
  #
  #     def process
  #       allowed_states.include?(state) or fail "Explode!!!"
  #       if state == on
  #         puts "Make coffee."
  #       else
  #         puts "Idle..."
  #       end
  #     end
  #   end
  #
  #   cm = CoffeeMaker.new
  #   cm.instance_eval do
  #     state      # => :off
  #     state on   # Sets state to :on
  #     # state tnt # should be avoided
  #     state      # => :on
  #     process    # => outputs "Make coffee."
  #   end
  #
  # @note Tins::SymbolMaker is an alternative for Tins::Constant in this example.
  #    While both approaches can be used to create symbolic references,
  #    SymbolMaker makes method calls return symbols, whereas Constant creates
  #    only the required constants. SymbolMaker can make debugging more
  #    difficult because it's less clear when a method call is returning a
  #    symbol versus being a real method call, typo, etc.
  module SymbolMaker
    # Handles missing method calls by returning the method name as a symbol.
    #
    # This method is called when Ruby cannot find a method in the current
    # object. Instead of raising NoMethodError, it returns the method name as a
    # symbol, enabling symbolic method handling throughout the application.
    # Only methods with no arguments are converted to symbols; methods with
    # arguments will raise the normal NoMethodError.
    #
    # @param id [Symbol] The missing method name
    # @param args [Array] Arguments passed to the missing method
    # @return [Symbol] The method name as a symbol (when no arguments)
    def method_missing(id, *args)
      if args.empty?
        id
      else
        super
      end
    end
  end

  # This module enables dynamic constant resolution by converting missing
  # constant references into symbols. When a constant is not found, instead of
  # raising NameError, the constant name is returned as a symbol. This is
  # particularly useful for creating DSLs, configuration systems, and symbolic
  # interfaces.
  #
  # @example Basic usage with missing constants
  #   class MyClass
  #     extend Tins::ConstantMaker
  #   end
  #
  #   # Missing constants return their names as symbols
  #   MyClass.const_get(:UNKNOWN_CONSTANT)  # => :UNKNOWN_CONSTANT
  module ConstantMaker
    # Handles missing constant references by returning the constant name as a
    # symbol.
    #
    # This method is called when Ruby cannot find a constant in the current
    # namespace. Instead of raising a NameError, it returns the constant name
    # as a symbol, enabling symbolic constant handling throughout the
    # application.
    #
    # @param id [Symbol] The missing constant name
    # @return [Symbol] The constant name as a symbol
    def const_missing(id)
      id
    end
  end

  # A module that provides blank slate class creation functionality.
  #
  # This module enables the creation of anonymous classes with restricted
  # method sets, allowing for precise control over object interfaces. Blank
  # slates are useful for security, DSL construction, testing, and creating
  # clean API surfaces.
  #
  # @example Basic usage with method whitelisting
  #   # Create a class that only responds to :length and :upcase methods
  #   RestrictedClass = Tins::BlankSlate.with(:length, :upcase, superclass: String)
  #
  #   obj = RestrictedClass.new('foo')
  #   obj.length         # => 3
  #   obj.upcase         # => 'FOO'
  #   obj.strip          # NoMethodError
  module BlankSlate
    # Creates an anonymous blank slate class with restricted method set.
    #
    # This method generates a new class that inherits from the specified superclass
    # (or Object by default) and removes all methods except those explicitly allowed.
    # The allowed methods can be specified as symbols, strings, or regular expressions.
    #
    # @param ids [Array<Symbol,String,Regexp>] Method names or patterns to allow
    # @option opts [Class] :superclass (Object) The base class to inherit from
    # @return [Class] A new anonymous class with only the specified methods available
    def self.with(*ids)
      opts = Hash === ids.last ? ids.pop : {}
      ids = ids.map { |id| Regexp === id ? id : id.to_s }
      klass = opts[:superclass] ? Class.new(opts[:superclass]) : Class.new
      klass.instance_eval do
        instance_methods.each do |m|
          m = m.to_s
          undef_method m unless m =~ /^(__|object_id)/ or ids.any? { |i| i === m }
        end
      end
      klass
    end
  end

  # See examples/recipe.rb and examples/recipe2.rb how this works at the
  # moment.
  module Deflect
    # The basic Deflect exception
    class DeflectError < StandardError; end

    class << self
      extend Tins::ThreadLocal

      # A thread local variable, that holds a DeflectorCollection instance for
      # the current thread.
      thread_local :deflecting
    end

    # A deflector is called with a _class_, a method _id_, and its
    # <i>*args</i>.
    class Deflector < Proc; end

    # This class implements a collection of deflectors, to make them available
    # by emulating Ruby's message dispatch.
    class DeflectorCollection
      def initialize
        @classes = {}
      end

      # Add a new deflector _deflector_ for class _klass_ and method name _id_,
      # and return self.
      #
      def add(klass, id, deflector)
        k = @classes[klass]
        k = @classes[klass] = {} unless k
        k[id.to_s] = deflector
        self
      end

      # Return true if messages are deflected for class _klass_ and method name
      # _id_, otherwise return false.
      def member?(klass, id)
        !!(k = @classes[klass] and k.key?(id.to_s))
      end

      # Delete the deflecotor class _klass_ and method name _id_. Returns the
      # deflector if any was found, otherwise returns true.
      def delete(klass, id)
        if k = @classes[klass]
          d = k.delete id.to_s
          @classes.delete klass if k.empty?
          d
        end
      end

      # Try to find a deflector for class _klass_ and method _id_ and return
      # it. If none was found, return nil instead.
      def find(klass, id)
        klass.ancestors.find do |k|
          if d = @classes[k] and d = d[id.to_s]
            return d
          end
        end
      end
    end

    @@sync = Sync.new

    # Start deflecting method calls named _id_ to the _from_ class using the
    # Deflector instance deflector.
    def deflect_start(from, id, deflector)
      @@sync.synchronize do
        Deflect.deflecting ||= DeflectorCollection.new
        Deflect.deflecting.member?(from, id) and
          raise DeflectError, "#{from}##{id} is already deflected"
        Deflect.deflecting.add(from, id, deflector)
        from.class_eval do
          define_method(id) do |*args|
            if Deflect.deflecting and d = Deflect.deflecting.find(self.class, id)
              d.call(self, id, *args)
            else
              super(*args)
            end
          end
        end
      end
    end

    # Return true if method _id_ is deflected from class _from_, otherwise
    # return false.
    def self.deflect?(from, id)
      Deflect.deflecting && Deflect.deflecting.member?(from, id)
    end

    # Return true if method _id_ is deflected from class _from_, otherwise
    # return false.
    def deflect?(from, id)
      Deflect.deflect?(from, id)
    end

    # Start deflecting method calls named _id_ to the _from_ class using the
    # Deflector instance deflector. After that yield to the given block and
    # stop deflecting again.
    def deflect(from, id, deflector)
      @@sync.synchronize do
        begin
          deflect_start(from, id, deflector)
          yield
        ensure
          deflect_stop(from, id)
        end
      end
    end

    # Stop deflection method calls named _id_ to class _from_.
    def deflect_stop(from, id)
      @@sync.synchronize do
        Deflect.deflecting.delete(from, id) or
          raise DeflectError, "#{from}##{id} is not deflected from"
        from.instance_eval { remove_method id }
      end
    end
  end

  # This module can be included into modules/classes to make the delegate
  # method available.
  module Delegate
    UNSET = Object.new

    private_constant :UNSET

    # A method to easily delegate methods to an object, stored in an
    # instance variable or returned by a method call.
    #
    # It's used like this:
    #   class A
    #     delegate :method_here, :@obj, :method_there
    #   end
    # or:
    #   class A
    #     delegate :method_here, :method_call, :method_there
    #   end
    #
    # _other_method_name_ defaults to method_name, if it wasn't given.
    def delegate(method_name, opts = {})
      to = opts[:to] || UNSET
      as = opts[:as] || method_name
      raise ArgumentError, "to argument wasn't defined" if to == UNSET
      to = to.to_s
      case
      when to[0, 2] == '@@'
        define_method(as) do |*args, &block|
          if self.class.class_variable_defined?(to)
            self.class.class_variable_get(to).__send__(method_name, *args, &block)
          end
        end
      when to[0] == ?@
        define_method(as) do |*args, &block|
          if instance_variable_defined?(to)
            instance_variable_get(to).__send__(method_name, *args, &block)
          end
        end
      when (?A..?Z).include?(to[0])
        define_method(as) do |*args, &block|
          Object.const_get(to).__send__(method_name, *args, &block)
        end
      else
        define_method(as) do |*args, &block|
          __send__(to).__send__(method_name, *args, &block)
        end
      end
    end
  end

  # This module includes the block_self module_function.
  module BlockSelf
    module_function

    # This method returns the receiver _self_ of the context in which _block_
    # was created.
    def block_self(&block)
      eval 'self', block.__send__(:binding)
    end
  end

  # This module contains a configurable method missing delegator and can be
  # mixed into a module/class.
  module MethodMissingDelegator

    # Including this module in your classes makes an _initialize_ method
    # available, whose first argument is used as method_missing_delegator
    # attribute. If a superior _initialize_ method was defined it is called
    # with all arguments but the first.
    module DelegatorModule
      include Tins::MethodMissingDelegator

      # The initialize method sets up the delegator and forwards additional
      # arguments to the superclass.
      #
      # @param delegator [ Object ] the object to delegate method calls to
      # @param a [ Array ] additional arguments to pass to the superclass initializer
      # @param b [ Proc ] optional block to be passed to the superclass initializer
      def initialize(delegator, *a, &b)
        self.method_missing_delegator = delegator
        super(*a, &b) if defined? super
      end
    end

    # This class includes DelegatorModule and can be used as a superclass
    # instead of including DelegatorModule.
    class DelegatorClass
      include DelegatorModule
    end

    # This object will be the receiver of all missing method calls, if it has a
    # value other than nil.
    attr_accessor :method_missing_delegator

    # Delegates all missing method calls to _method_missing_delegator_ if this
    # attribute has been set. Otherwise it will call super.
    def method_missing(id, *a, &b)
      unless method_missing_delegator.nil?
        method_missing_delegator.__send__(id, *a, &b)
      else
        super
      end
    end
  end

  # A module that provides parameterization capabilities for other modules.
  #
  # This module enables dynamic configuration of modules through a common
  # interface, allowing for flexible composition and customization of module
  # behavior at runtime.
  #
  # @example Basic usage with a custom parameterizable module
  #   module MyModule
  #     include Tins::ParameterizedModule
  #
  #     def self.parameterize(options = {})
  #       # Custom parameterization logic
  #       @options = options
  #       self
  #     end
  #   end
  #
  #   # Usage
  #   configured_module = MyModule.parameterize_for(some_option: 'value')
  #   MyModule.instance_variable_get(:@options) # => {some_option: "value"}
  module ParameterizedModule
    # Configures the module using the provided arguments and optional block.
    #
    # This method checks if the including module responds to `parameterize` and calls
    # it with the given arguments. If no `parameterize` method exists, it returns
    # the module itself unchanged.
    #
    # @param args [Array] Arguments to pass to the parameterize method
    # @yield [block] Optional block to be passed to the parameterize method
    # @return [Module] The configured module or self if no parameterization occurs
    def parameterize_for(*args, &block)
      respond_to?(:parameterize) ? parameterize(*args, &block) : self
    end
  end

  # A module that provides parameterized module creation capabilities.
  #
  # This module enables the creation of new modules by filtering methods from
  # existing modules, allowing for flexible composition and interface
  # segregation at runtime.
  #
  # @example
  #   class MixedClass
  #     extend Tins::FromModule
  #
  #     include MyModule     # has foo, bar and baz methods
  #     include from module: MyIncludedModule, methods: :foo
  #     include from module: MyIncludedModule2, methods: :bar
  #   end
  #
  #   c = MixedClass.new
  #   assert_equal :foo,  c.foo # from MyIncludedModule
  #   assert_equal :bar2, c.bar # from MyIncludedModule2
  #   assert_equal :baz,  c.baz # from MyModule
  #
  # @example Create a stack-like class using Array methods
  #   class Stack < Class.from(module: Array, methods: %i[ push pop last ])
  #   end
  #
  #   s = Stack.new
  #   s.push(1)
  #   s.push(2)
  #   s.last  # => 2
  #   s.pop   # => 2
  #   s.last  # => 1
  module FromModule
    include ParameterizedModule

    alias from parameterize_for

    # Creates a new module by filtering methods from an existing module.
    #
    # This method duplicates the specified module and removes all methods
    # except those explicitly listed in the :methods option. This enables
    # creating specialized interfaces
    # from existing modules.
    #
    # @param opts [Hash] Configuration options
    # @option opts [Module] :module (required) The source module (or class) to filter methods from
    # @option opts [Array<Symbol>] :methods (required) Array of method names to preserve
    # @return [Module] A new module with only the specified methods available
    def parameterize(opts = {})
      modul = opts[:module] or raise ArgumentError, 'option :module is required'
      import_methods = Array(opts[:methods])
      result = modul.dup
      remove_methods = modul.instance_methods.map(&:to_sym) - import_methods.map(&:to_sym)
      remove_methods.each do |m|
        begin
          result.__send__ :remove_method, m
        rescue NameError
          # Method might already be removed or not exist
        end
      end
      result
    end
  end

  # A module that provides thread-local stack-based scoping functionality.
  #
  # This module implements a context management system where each thread
  # maintains its own isolated scope stacks. It's particularly useful for
  # tracking nested contexts in multi-threaded applications.
  #
  # @example Basic stack operations
  #   Scope.scope_push("context1")
  #   Scope.scope_push("context2")
  #   Scope.scope_top  # => "context2"
  #   Scope.scope_pop  # => "context2"
  #   Scope.scope_top  # => "context1"
  #
  # @example Block-based context management
  #   Scope.scope_block("request_context") do
  #     # Within this block, "request_context" is active
  #   end
  #   # Automatically cleaned up when block exits
  #
  # @example Nested scope blocks
  #   Scope.scope_block("outer_context") do
  #     Scope.scope_block("inner_context") do
  #       Scope.scope_top  # => "inner_context"
  #     end
  #     Scope.scope_top  # => "outer_context"
  #   end
  #   Scope.scope_top  # => nil (empty stack)
  #
  # @example Multiple named scopes
  #   Scope.scope_push("frame1", :database)
  #   Scope.scope_push("frame2", :database)
  #   Scope.scope_get(:database)  # => ["frame1", "frame2"]
  module Scope
    # Pushes a scope frame onto the top of the specified scope stack.
    #
    # @param scope_frame [Object] The object to push onto the stack
    # @param name [Symbol] The name of the scope to use (defaults to :default)
    # @return [self] Returns self to enable method chaining
    def scope_push(scope_frame, name = :default)
      scope_get(name).push scope_frame
      self
    end

    # Pops a scope frame from the top of the specified scope stack.
    #
    # If the scope becomes empty after popping, it is automatically removed
    # from Thread.current to prevent memory leaks.
    #
    # @param name [Symbol] The name of the scope to use (defaults to :default)
    # @return [self] Returns self to enable method chaining
    def scope_pop(name = :default)
      scope_get(name).pop
      scope_get(name).empty? and Thread.current[name] = nil
      self
    end

    # Returns the top element of the specified scope stack without removing it.
    #
    # @param name [Symbol] The name of the scope to use (defaults to :default)
    # @return [Object, nil] The top element of the stack or nil if empty
    def scope_top(name = :default)
      scope_get(name).last
    end

    # Iterates through the specified scope stack in reverse order.
    #
    # @param name [Symbol] The name of the scope to use (defaults to :default)
    # @yield [frame] Yields each frame from top to bottom
    # @return [Enumerator] If no block is given, returns an enumerator
    def scope_reverse(name = :default, &block)
      scope_get(name).reverse_each(&block)
    end

    # Executes a block within the context of a scope frame.
    #
    # Automatically pushes the scope frame before yielding and pops it after
    # the block completes, even if an exception occurs.
    #
    # @param scope_frame [Object] The scope frame to push
    # @param name [Symbol] The name of the scope to use (defaults to :default)
    # @yield [void] The block to execute within the scope
    # @return [Object] The result of the block execution
    def scope_block(scope_frame, name = :default)
      scope_push(scope_frame, name)
      yield
    ensure
      scope_pop(name)
    end

    # Retrieves or initializes the specified scope stack.
    #
    # @param name [Symbol] The name of the scope to retrieve (defaults to :default)
    # @return [Array] The scope stack for the given name
    def scope_get(name = :default)
      Thread.current[name] ||= []
    end

    # Returns a copy of the specified scope stack.
    #
    # @param name [Symbol] The name of the scope to retrieve (defaults to :default)
    # @return [Array] A duplicate of the scope stack
    def scope(name = :default)
      scope_get(name).dup
    end
  end

  # A module that provides dynamic scope-based variable binding with hash
  # contexts.
  #
  # This module extends the basic Scope functionality to enable dynamic
  # variable binding where variables can be set and accessed like methods, but
  # stored in hash-based contexts. It's particularly useful for building DSLs,
  # template engines, and context-sensitive applications.
  #
  # @example Basic dynamic scoping
  #   include Tins::DynamicScope
  #
  #   dynamic_scope do
  #     self.foo = "value"  # Sets variable in current scope
  #     puts foo           # => "value" (reads from current scope)
  #   end
  #
  # @example Nested scopes with variable shadowing
  #   include Tins::DynamicScope
  #
  #   dynamic_scope do
  #     self.foo = "outer"
  #     dynamic_scope do
  #       self.foo = "inner"  # Shadows outer foo only in inner scope
  #       puts foo           # => "inner"
  #     end
  #     puts foo             # => "outer" (restored from outer scope)
  #   end
  #
  # @example Variable existence checking
  #   include Tins::DynamicScope
  #
  #   dynamic_scope do
  #     assert_equal false, dynamic_defined?(:foo)
  #     self.foo = "value"
  #     assert_equal true, dynamic_defined?(:foo)
  #   end
  module DynamicScope
    # A specialized Hash subclass for dynamic scope contexts.
    #
    # This class automatically converts string keys to symbols for more
    # convenient variable access.
    class Context < Hash
      # Retrieves a value by symbolized key.
      def [](name)
        super name.to_sym
      end

      # Sets a value with a symbolized key.
      def []=(name, value)
        super name.to_sym, value
      end
    end

    include Scope

    # The name of the dynamic scope to use (defaults to :variables).
    attr_accessor :dynamic_scope_name

    # Checks if a variable is defined in any active dynamic scope.
    #
    # @param id [Symbol] The variable name to check
    # @return [Boolean] true if the variable is defined in any active scope, false otherwise
    def dynamic_defined?(id)
      self.dynamic_scope_name ||= :variables
      scope_reverse(dynamic_scope_name) { |c| c.key?(id) and return true }
      false
    end

    # Creates a new dynamic scope context.
    #
    # This method pushes a new Context object onto the scope stack and yields
    # to the provided block. When the block completes, the context is automatically
    # popped from the stack.
    #
    # @yield [void] The block to execute within the dynamic scope
    # @return [Object] The result of the block execution
    def dynamic_scope(&block)
      self.dynamic_scope_name ||= :variables
      scope_block(Context.new, dynamic_scope_name, &block)
    end

    # Handles method calls that don't match existing methods.
    #
    # This implements the core dynamic variable binding behavior:
    # - For read operations (no arguments): Looks up the method name in active scopes
    #   and returns the value if found, otherwise delegates to super for normal method resolution
    # - For write operations (one argument + = suffix): Sets the value in current scope
    # - For all other cases: Delegates to super for normal method resolution
    #
    # @param id [Symbol] The method name being called
    # @param args [Array] Arguments passed to the method
    # @return [Object] The result of the dynamic variable access or delegation
    def method_missing(id, *args)
      self.dynamic_scope_name ||= :variables
      if args.empty? and scope_reverse(dynamic_scope_name) { |c| c.key?(id) and return c[id] }
        super
      elsif args.size == 1 and id.to_s =~ /(.*?)=\Z/
        c = scope_top(dynamic_scope_name) or super
        c[$1] = args.first
      else
        super
      end
    end
  end
end
# DSLKit provides a comprehensive framework for building Domain Specific Languages
# and configuration systems in Ruby.
#
# DSLKit is designed to make it easy to create clean, expressive APIs that feel
# natural to Ruby developers. It provides a collection of utilities for:
#
# - Creating method-based accessors and constants
# - Working with singleton classes and eigenclasses
# - Building thread-safe global variables
# - Implementing dynamic code evaluation
# - Creating symbolic method handling
# - Deflecting method calls for interception
# - Providing delegate patterns for method forwarding
# - Building blank slates for clean API surfaces
#
# The framework is organized around several key modules:
#
# - Tins::DSLAccessor: For creating configurable accessors with default values
# - Tins::Constant: For creating method-based constants
# - Tins::Eigenclass: For working with singleton classes
# - Tins::ClassMethod: For defining class methods dynamically
# - Tins::ThreadGlobal: For thread-safe global variables
# - Tins::Interpreter: For dynamic code evaluation
# - Tins::SymbolMaker: For symbolic method handling
# - Tins::ConstantMaker: For symbolic constant handling
# - Tins::Deflect: For method call interception
# - Tins::Delegate: For method delegation patterns
# - Tins::BlankSlate: For creating clean API surfaces
#
# @example Basic DSL usage
#   class Config
#     extend Tins::DSLAccessor
#     dsl_accessor :port, 8080
#     dsl_accessor :host, 'localhost'
#   end
#
#   config = Config.new
#   config.port    # => 8080
#   config.port 8081  # Sets port to 8081
#
# @example Method deflection
#   class Calculator
#     def add(a, b)
#       a + b
#     end
#   end
#
#   calc = Calculator.new
#   Tins::Deflect.deflect(Calculator, :add) do |obj, method, *args|
#     # Custom behavior for add method
#     args.sum
#   end
#
#   calc.add(1, 2, 3)  # => 6 (sum instead of addition)
#
# @see Tins::DSLAccessor
# @see Tins::Constant
# @see Tins::Eigenclass
# @see Tins::ClassMethod
# @see Tins::ThreadGlobal
# @see Tins::Interpreter
# @see Tins::SymbolMaker
# @see Tins::Deflect
# @see Tins::Delegate
# @see Tins::BlankSlate
DSLKit = Tins
