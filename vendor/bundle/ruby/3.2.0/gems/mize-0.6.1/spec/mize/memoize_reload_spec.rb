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

describe Mize::Reload do
  before do
    Mize.wrapped.clear

    class Foo
      memoize method: :foo
    end
    Foo.reset
  end

  let(:foo) { Foo.new }

  describe '#reload' do
    it 'clears cache after reload' do
      expect(foo.foo).to eq 1
      expect(foo.foo).to eq 1
      expect(foo.reload.foo).to eq 2
    end
  end
end
