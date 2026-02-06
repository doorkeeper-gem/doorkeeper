require 'spec_helper'

class Foo
  def self.reset
    @@foo = nil
  end

  def reload
    @reload = true
    self
  end

  def foo(*a)
    @@foo ||= 0
    @@foo += 1
  end
end

describe Mize, 'cache_clear' do
  before do
    Mize.wrapped.clear

    class Foo
      memoize method: :foo
    end
  end

  let(:foo) { Foo.new }

  describe '#cache_clear' do
    it 'clears cache after Mize.cache_clear' do
      expect(foo.foo).to eq 1
      expect(foo.foo).to eq 1
      expect(foo.__send__(:__mize_cache__)).to be_a Mize::CacheProtocol
      Mize.cache_clear
      expect(foo.foo).to eq 2
    end
  end
end
