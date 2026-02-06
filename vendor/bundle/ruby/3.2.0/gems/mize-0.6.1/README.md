# Mize


## Introduction

Memoization is a powerful technique for improving the performance of
computationally expensive functions or methods by caching and reusing
previously computed results. However, implementing memoization correctly can be
tricky, especially when dealing with complex data structures or scenarios where
cache invalidation is critical.

## Description

The `mize` library provides a simple and flexible way to memoize methods and
functions in Ruby, making it easier for developers to write high-performance
code without the need for manual caching implementations. In this README.md,
we'll explore how `mize` can help you optimize your Ruby projects using
memoization techniques.

## Installation

You can use rubygems to fetch the gem and install it for you:

    # gem install mize

You can also put this line into your `Gemfile`

    gem 'mize'

and bundle.

## Usage

Memoizes methods, that is the values depend on the receiver, like this:

```
class A
  @@c = 0

  memoize method:
  def foo(x)
    "foo #{x} #{@@c += 1}"
  end
end

a1 = A.new
a1.foo(23) # => "foo 23 1"
a1.foo(23) # => "foo 23 1"
a2 = A.new
a2.foo(23) # => "foo 23 2"
a2.foo(23) # => "foo 23 2"
a2.mize_cache_clear
a2.foo(23) # => "foo 23 3"
a1.foo(23) # => "foo 23 1"
```

Memoizes functions, that is the values do not depend on the receiver, like
this:

```
class B
  @@c = 0

  memoize function:
  def foo(x)
    "foo #{x} #{@@c += 1}"
  end
end

b1 = B.new
b1.foo(23) # => "foo 23 1"
b1.foo(23) # => "foo 23 1"
b2 = B.new
b2.foo(23) # => "foo 23 1"
b2.foo(23) # => "foo 23 1"
B.mize_cache_clear
b2.foo(23) # => "foo 23 2"
b1.foo(23) # => "foo 23 2"
```

## Download

The homepage of this library is located at

* https://github.com/flori/mize

## Author

[Florian Frank](mailto:flori@ping.de)

## License

This software is licensed under MIT license.
