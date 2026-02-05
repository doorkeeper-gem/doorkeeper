#!/usr/bin/env ruby

require 'tins'

if $0 == __FILE__
  class Foo
    include Tins::DynamicScope

    def let(bindings = {})
      dynamic_scope do
        bindings.each { |name, value| send("#{name}=", value) }
        yield
      end
    end

    def twice(x)
      2 * x
    end

    def test
      let x: 1, y: twice(1) do
        let z: twice(x) do
          puts "#{x} * #{y} == #{z} # => #{x * y == twice(x)}"
        end
      end
    end
  end

  Foo.new.test
end
