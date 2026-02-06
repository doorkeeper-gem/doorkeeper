require 'test_helper'

class TL
  def initialize
    make_baz
  end

  extend Tins::ThreadLocal
  thread_local :foo

  extend Tins::ThreadLocal
  thread_local :foo2 do {} end

  include Tins::ThreadLocal
  def make_baz
    instance_thread_local :baz
  end

  extend Tins::ThreadGlobal
  thread_global :bar

  thread_global :bar2 do {} end
end

class IE

  def initialize(&block)
    @block = block
  end

  def exec
    instance_exec(&@block)
  end

  def foo
    :foo
  end
end

class C
  extend Tins::Constant

  constant :foo

  constant :bar, :baz
end

class DA
  extend Tins::DSLAccessor

  dsl_accessor :foo

  dsl_accessor :bar, :bar

  dsl_accessor :baz do :baz end

  dsl_accessor :quux, :qu, :ux

  dsl_reader :on, true

  dsl_reader :off, false

  dsl_reader :states do
    [ on, off ]
  end

  dsl_reader :abc, *%w[a b c]

  dsl_lazy_accessor :lazy do
    :foo
  end

  dsl_lazy_accessor :lazy_no_default
end

class I
  include Tins::Interpreter

  def foo
    :foo
  end

  def y
    2
  end
end

class S
  include Tins::SymbolMaker
end

module K
  extend Tins::ConstantMaker
end

module D
  extend Tins::Deflect
end

class D3 < Tins::MethodMissingDelegator::DelegatorClass
end

require 'test/unit'
require 'tempfile'

class PoliteTest < Test::Unit::TestCase
  def setup
    @tl = TL.new
    @tl2 = TL.new
    @ie = IE.new { foo }
    @c  = C.new
    @da = DA.new
    @i  = I.new
  end

  def test_version
    assert_equal Tins::VERSION_ARRAY * '.', Tins::VERSION
  end

  def test_thread_local
    assert_nil @tl.foo
    @tl.foo = 1
    assert_equal 1, @tl.foo
    new_foo = nil
    thread = Thread.new do
      @tl.foo = 2
      new_foo = @tl.foo
    end
    thread.join
    assert_equal 2, new_foo
    assert_equal 1, @tl.foo
    assert_equal @tl.baz, @tl2.baz
  end

  def test_thread_local_with_default
    assert_kind_of Hash, @tl.foo2
    @tl.foo2[:hi] = 1
    assert_equal 1, @tl.foo2[:hi]
    thread = Thread.new do
      assert_kind_of Hash, @tl.foo2
      assert_nil @tl.foo2[:hi]
      @tl.foo2[:hi] = 2
    end
    thread.join
    assert_equal 1, @tl.foo2[:hi]
  end

  def test_instance_thread_local
    assert_nil @tl.baz
    @tl.baz = 1
    assert_equal 1, @tl.baz
    new_foo = nil
    thread = Thread.new do
      @tl.baz = 2
      new_foo = @tl.baz
    end
    thread.join
    assert_equal 2, new_foo
    assert_equal 1, @tl.baz
    assert_not_equal @tl.baz, @tl2.baz
  end

  def test_thread_global
    assert_nil @tl.bar
    @tl.bar = 1
    assert_equal 1, @tl.bar
    new_bar = nil
    thread = Thread.new do
      @tl.bar = 2
      new_bar = @tl.bar
    end
    thread.join
    assert_equal 2, new_bar
    assert_equal 2, @tl.bar
  end

  def test_thread_global_with_default
    assert_kind_of Hash, @tl.bar2
    @tl.bar2[:hi] = 1
    assert_equal 1, @tl.bar2[:hi]
    thread = Thread.new do
      assert_kind_of Hash, @tl.bar2
      assert_equal 1, @tl.bar2[:hi]
    end
    thread.join
    assert_equal 1, @tl.bar2[:hi]
  end

  def test_instance_exec
    assert_equal :foo, @ie.foo
    assert_equal :foo, @ie.exec
    @ie.freeze
    assert_equal :foo, @ie.foo
    assert_equal :foo, @ie.exec
  end

  def test_constant
    assert_equal :foo, @c.foo
    assert_equal :baz, @c.bar
  end

  def test_dsl_accessor
    assert_nil @da.foo
    assert_equal :bar, @da.bar
    assert_equal :baz, @da.baz
    assert_equal [:qu, :ux], @da.quux
    @da.foo 1
    @da.bar 2
    @da.baz 3
    assert_equal 1, @da.foo
    assert_equal 2, @da.bar
    assert_equal 3, @da.baz
  end

  def test_dsl_reader
    assert_equal true, @da.on
    assert_equal false, @da.off
    assert_raise(ArgumentError) do
      @da.on false
    end
    assert_equal [ @da.on, @da.off ], @da.states
    assert_equal %w[a b c], @da.abc
    @da.abc << 'd'
    assert_equal %w[a b c d], @da.abc
    @da.instance_variable_set :@abc, %w[a b c]
    assert_equal %w[a b c], @da.abc
  end

  def test_lazy_accessor
    assert_equal :foo, @da.lazy
    @da.lazy { :bar }
    assert_equal :bar, @da.lazy
    assert_equal nil, @da.lazy_no_default
    @da.lazy_no_default { :bar }
    assert_equal :bar, @da.lazy_no_default
  end

  def test_dsl_accessor_multiple
    assert_nil @da.foo
    assert_equal :bar, @da.bar
    @da.foo 1, 2
    @da.bar [1, 2]
    assert_equal [1, 2], @da.foo
    assert_equal [1, 2], @da.bar
    @da.bar [1, 2, *@da.bar]
    assert_equal [1, 2] * 2, @da.bar
  end

  def test_interpreter
    assert_equal :foo, @i.interpret('foo')
    temp = Tempfile.new('foo')
    temp.write 'foo'
    temp.rewind
    assert_equal :foo, @i.interpret(temp)
  end

  def test_interpreter_with_args
    assert_equal 3, @i.interpret('|x| x + y', 1)
    temp = Tempfile.new('foo')
    temp.write '|x| x + y'
    temp.rewind
    assert_equal 3, @i.interpret(temp, 1)
  end

  def test_symbol_maker
    s = S.new
    assert_equal(:foo, s.instance_exec { foo })
    assert_raise(NoMethodError) { s.instance_exec { foo 1 }}
  end

  def test_constant_maker
    assert_equal(:FOO, K::FOO)
  end

  def test_deflect_block
    assert_raise(NoMethodError) { 1.foo }
    assert !D.deflect?(Integer, :foo)
    D.deflect(Integer, :foo, Tins::Deflect::Deflector.new { :foo }) do
      assert_equal :foo, 1.foo
      assert D.deflect?(Integer, :foo)
    end
    assert !D.deflect?(Integer, :foo)
    assert_raise(NoMethodError) { 1.foo }
  end

  def test_deflect
    assert_raise(NoMethodError) { 1.foo }
    assert !D.deflect?(Integer, :foo)
    D.deflect_start(Integer, :foo, Tins::Deflect::Deflector.new { :foo })
    assert_equal :foo, 1.foo
    assert D.deflect?(Integer, :foo)
    t = Thread.new do
      assert !D.deflect?(Integer, :foo)
      assert_raise(NoMethodError) { 1.foo }
    end
    t.join
    D.deflect_stop(Integer, :foo)
    assert !D.deflect?(Integer, :foo)
    assert_raise(NoMethodError) { 1.foo }
  end

  def test_deflect_method_missing
    assert_raise(NoMethodError) { 1.foo }
    assert !D.deflect?(Integer, :method_missing)
    D.deflect_start(Integer, :method_missing, Tins::Deflect::Deflector.new { :foo })
    assert_equal :foo, 1.foo
    assert D.deflect?(Integer, :method_missing)
    t = Thread.new do
      assert !D.deflect?(Integer, :method_missing)
      assert_raise(NoMethodError) { 1.foo }
    end
    t.join
    D.deflect_stop(Integer, :method_missing)
    assert !D.deflect?(Integer, :method_missing)
    assert_raise(NoMethodError) { 1.foo }
  end

  def test_delegate_d3
    d = D3.new []
    assert_equal 0, d.size
    d.push 1
    assert_equal [1], d.map { |x| x }
    d.push 2
    assert_equal [1, 2], d.map { |x| x }
    d.push 3
    assert_equal [1, 2, 3], d.map { |x| x }
  end
end
