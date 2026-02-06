require 'spec_helper'

class FooBar
  class << self
    def reset
      @@foo     = nil
      @@footsie = nil
      @@bar     = nil
      @@baz     = nil
      @@foo_nil_stored     = nil
      @@foo_nil_not_stored = nil
      Mize.cache_clear
    end

    def foo_nil_stored
      @@foo_nil_stored
    end

    def foo_nil_not_stored
      @@foo_nil_not_stored
    end
  end

  def foo(*a)
    @@foo ||= 0
    @@foo += 1
  end
  memoize method: :foo

  def foo2(arg: 22)
    @@foo2 ||= arg
    @@foo2 += 1
  end
  memoize method: :foo2

  def footsie(*a)
    @@footsie ||= 0
    @@footsie += 1
  end
  protected :footsie
  memoize method: :footsie

  def bar(*a)
    @@bar ||= 0
    @@bar += 1
  end
  memoize function: :bar

  def bar2(arg: 22)
    @@bar2 ||= arg
    @@bar2 += 1
  end
  memoize function: :bar2

  def foo_nil_stored(*a)
    @@foo_nil_stored ||= 0
    @@foo_nil_stored += 1
    nil
  end
  memoize method: :foo_nil_stored, store_nil: true

  def foo_nil_not_stored(*a)
    @@foo_nil_not_stored ||= 0
    @@foo_nil_not_stored += 1
    nil
  end
  memoize method: :foo_nil_not_stored, store_nil: false

  private

  def baz(*a)
    @@baz ||= 0
    @@baz += 1
  end
  memoize function: :baz
end

describe Mize do
  before do
    FooBar.reset
    class ::Mize::DefaultCache
      def empty?
        s = 0
        each_name { s += 1 }
        s == 0
      end
    end
  end

  let(:fb1) { FooBar.new }

  let(:fb2) { FooBar.new }

  context 'memoize method' do
    it 'can cache methods' do
      expect(fb1.__send__(:__mize_cache__)).to be_empty
      expect(fb2.__send__(:__mize_cache__)).to be_empty
      expect(fb1.foo(1, 2)).to eq 1
      expect(fb2.foo(1, 2)).to eq 2
      expect(fb1.foo(1, 2, 3)).to eq 3
      expect(fb2.foo(1, 2, 3)).to eq 4
      expect(fb1.foo(1, 2)).to eq 1
      expect(fb2.foo(1, 2)).to eq 2
      fb1.mize_cache_clear
      fb2.mize_cache_clear
      expect(fb1.__send__(:__mize_cache__)).to be_empty
      expect(fb2.__send__(:__mize_cache__)).to be_empty
      expect(fb1.foo(1, 2)).to eq 5
      expect(fb2.foo(1, 2)).to eq 6
      expect(fb1.foo(1, 2)).to eq 5
      expect(fb2.foo(1, 2)).to eq 6
      expect(fb1.__send__(:__mize_cache__)).not_to be_empty
      expect(fb2.__send__(:__mize_cache__)).not_to be_empty
    end

    it 'can cache methods with kargs' do
      expect(fb1.__send__(:__mize_cache__)).to be_empty
      expect(fb2.__send__(:__mize_cache__)).to be_empty
      expect(fb1.foo2()).to eq 23
      expect(fb2.foo2()).to eq 24
      expect(fb1.foo2(arg: 123)).to eq 25
      expect(fb2.foo2(arg: 123)).to eq 26
      expect(fb1.foo2()).to eq 23
      expect(fb2.foo2()).to eq 24
      fb1.mize_cache_clear
      fb2.mize_cache_clear
      expect(fb1.__send__(:__mize_cache__)).to be_empty
      expect(fb2.__send__(:__mize_cache__)).to be_empty
      expect(fb1.foo2()).to eq 27
      expect(fb2.foo2()).to eq 28
      expect(fb1.foo2()).to eq 27
      expect(fb2.foo2()).to eq 28
      expect(fb1.foo2(arg: 123)).to eq 29
      expect(fb2.foo2(arg: 123)).to eq 30
      expect(fb1.__send__(:__mize_cache__)).not_to be_empty
      expect(fb2.__send__(:__mize_cache__)).not_to be_empty
    end

    it 'can cache protected methods' do
      expect(fb1.__send__(:__mize_cache__)).to be_empty
      expect(fb2.__send__(:__mize_cache__)).to be_empty
      expect(fb1.__send__(:footsie, 1, 2)).to eq 1
      expect(fb2.__send__(:footsie, 1, 2)).to eq 2
      expect(fb1.__send__(:footsie, 1, 2, 3)).to eq 3
      expect(fb2.__send__(:footsie, 1, 2, 3)).to eq 4
      expect(fb1.__send__(:footsie, 1, 2)).to eq 1
      expect(fb2.__send__(:footsie, 1, 2)).to eq 2
      fb1.mize_cache_clear
      fb2.mize_cache_clear
      expect(fb1.__send__(:__mize_cache__)).to be_empty
      expect(fb2.__send__(:__mize_cache__)).to be_empty
      expect(fb1.__send__(:footsie, 1, 2)).to eq 5
      expect(fb2.__send__(:footsie, 1, 2)).to eq 6
      expect(fb1.__send__(:footsie, 1, 2)).to eq 5
      expect(fb2.__send__(:footsie, 1, 2)).to eq 6
      expect(fb1.__send__(:__mize_cache__)).not_to be_empty
      expect(fb2.__send__(:__mize_cache__)).not_to be_empty
    end

    it 'can clear caches for a single method' do
      expect(fb1.__send__(:__mize_cache__)).to be_empty
      expect(fb1.__send__(:footsie, 1, 2)).to eq 1
      expect(fb1.foo(1)).to eq 1
      fb1.mize_cache_clear_name :foo
      expect(fb1.__send__(:__mize_cache__)).not_to be_empty
      expect(fb1.__send__(:footsie, 1, 2)).to eq 1
      expect(fb1.__send__(:foo, 1, 2)).to eq 2
    end

    it 'can store nil' do
      expect(fb1.__send__(:__mize_cache__)).to be_empty
      expect(FooBar.foo_nil_stored).to be_nil
      expect(fb1.foo_nil_stored(1, 2)).to be_nil
      expect(fb1.__send__(:__mize_cache__)).not_to be_empty
      expect(FooBar.foo_nil_stored).to eq 1
      expect(fb1.foo_nil_stored(1, 2)).to be_nil
      expect(FooBar.foo_nil_stored).to eq 1
    end

    it 'can skip storing nil' do
      expect(fb1.__send__(:__mize_cache__)).to be_empty
      expect(FooBar.foo_nil_not_stored).to be_nil
      expect(fb1.foo_nil_not_stored(1, 2)).to be_nil
      expect(fb1.__send__(:__mize_cache__)).to be_empty
      expect(FooBar.foo_nil_not_stored).to eq 1
      expect(fb1.foo_nil_not_stored(1, 2)).to be_nil
      expect(fb1.__send__(:__mize_cache__)).to be_empty
      expect(FooBar.foo_nil_not_stored).to eq 2
    end

    it 'only wraps once' do
      class FooBar2
        def foo
        end
      end
      expect(FooBar2).to receive(:memoize_apply_visibility).and_call_original
      class FooBar2
        memoize method: :foo
      end
      expect(FooBar2).not_to receive(:memoize_apply_visibility)
      class FooBar2
        memoize method: :foo
      end
      expect do
        class FooBar2
          memoize method: :foo, store_nil: false
        end
      end.to raise_error(ArgumentError)
    end
  end

  context 'memoize function' do
    it 'can cache functions' do
      expect(FooBar.__send__(:__mize_cache__)).to be_empty
      expect(fb1.bar(1, 2)).to eq 1
      expect(fb2.bar(1, 2)).to eq 1
      expect(fb1.bar(1, 2, 3)).to eq 2
      expect(fb2.bar(1, 2, 3)).to eq 2
      expect(fb1.bar(1, 2)).to eq 1
      expect(fb2.bar(1, 2)).to eq 1
      FooBar.mize_cache_clear
      expect(fb1.bar(1, 2)).to eq 3
      expect(fb2.bar(1, 2)).to eq 3
      expect(FooBar.__send__(:__mize_cache__)).not_to be_empty
    end

    it 'can cache functions with kargs' do
      expect(FooBar.__send__(:__mize_cache__)).to be_empty
      expect(fb1.bar2).to eq 23
      expect(fb2.bar2).to eq 23
      expect(fb1.bar2(arg: 123)).to eq 24
      expect(fb2.bar2(arg: 123)).to eq 24
      expect(fb1.bar2).to eq 23
      expect(fb2.bar2).to eq 23
      FooBar.mize_cache_clear
      expect(fb1.bar2).to eq 25
      expect(fb2.bar2).to eq 25
      expect(FooBar.__send__(:__mize_cache__)).not_to be_empty
    end

    it 'can cache private functions' do
      expect(FooBar.__send__(:__mize_cache__)).to be_empty
      expect(fb1.__send__(:baz, 1, 2)).to eq 1
      expect(fb2.__send__(:baz, 1, 2)).to eq 1
      expect(fb1.__send__(:baz, 1, 2, 3)).to eq 2
      expect(fb2.__send__(:baz, 1, 2, 3)).to eq 2
      expect(fb1.__send__(:baz, 1, 2)).to eq 1
      expect(fb2.__send__(:baz, 1, 2)).to eq 1
      FooBar.mize_cache_clear
      expect(fb1.__send__(:baz, 1, 2)).to eq 3
      expect(fb2.__send__(:baz, 1, 2)).to eq 3
      expect(FooBar.__send__(:__mize_cache__)).not_to be_empty
    end

    it 'can clear caches for a single function' do
      expect(FooBar.__send__(:__mize_cache__)).to be_empty
      expect(fb1.__send__(:baz, 1, 2)).to eq 1
      expect(fb1.bar(1)).to eq 1
      fb1.mize_cache_clear_name :bar
      expect(FooBar.__send__(:__mize_cache__)).not_to be_empty
      expect(fb1.__send__(:baz, 1, 2)).to eq 1
      expect(fb1.__send__(:bar, 1, 2)).to eq 2
    end
  end
end
