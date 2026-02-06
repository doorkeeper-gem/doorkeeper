# Tins - Useful tools library in Ruby

## Description

A collection of useful Ruby utilities that extend the standard library with
practical conveniences. Tins provides lightweight, dependency-free tools for
common programming tasks.

## Documentation

Complete API documentation is available at: [GitHub.io](https://flori.github.io/tins/)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tins'
```

Or:

```ruby
gem 'tins', require 'tins/xt'
```

to automatically extend some core classes with useful methods.

And then execute:

 $ bundle install

Or install it yourself as:

 $ gem install tins

## Usage

```ruby
# Load all utilities

require 'tins'

# Load all utilities and extends core classes with useful methods
require 'tins/xt'
```
## Some Usage Examples

### Duration Handling

```ruby
require 'tins/duration'

duration = Tins::Duration.new(9000)
puts duration.to_s # "02:30:00"
puts duration.to_i # 9000 (seconds)

# Parse durations from strings
Tins::Duration.parse('2h 30m', template: '%hh %mm') # 9000 (seconds)
```

### Unit Conversion

```ruby
require 'tins/unit'

bytes = Tins::Unit.parse('1.5 GB', unit: ?B).to_i # => 1610612736
puts Tins::Unit.format(bytes, unit: 'B') # "1.500000 GB"
```

### Secure File Writing

```ruby
require 'tins/xt/secure_write'

# Write files safely (atomic operation)
File.secure_write('config.json', '{"key": "value"}')
```

### Time Freezing for Testing

```ruby
require 'tins/xt/time_freezer'

# Freeze time during testing
Tins::TimeFreezer.freeze(Time.new('2011-12-13 14:15:16')) do
  puts Time.now # Always returns the frozen time
end
```

### Building blocks for DSLs

```ruby
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
        "#{x} * #{y} == #{z} # => #{x * y == twice(x)}"
      end
    end
  end
end

Foo.new.test # "1 * 2 == 2 # => true"
```

### Core Class Extensions (xt)

When you require `tins/xt`, some useful methods are added to core classes:

```ruby
default_options = {
  format: :json,
  timeout: 30,
  retries: 3
}

user_options = { timeout: 60 }
options = user_options | default_options
# => { format: :json, timeout: 60, retries: 3 }

'1.10.3'.version < '1.9.2'.version # => false

add_one         = -> x { x + 1 }
multiply_by_two = -> x { x * 2 }
composed        = multiply_by_two * add_one
composed.(5) # => 12

# For Testing
>> o = Object.new
>> o.puts # => private method, NoMethodError
>> o = o.expose
>> o.puts "hello"
hello
```

### Hash Symbolization

```ruby
require 'tins/hash_symbolize_keys_recursive'

hash = {
  'name' => 'John',
  'age' => 30,
  'address' => {
    'street' => '123 Main St'
  }
}
hash.symbolize_keys_recursive! # Converts all keys to symbols recursively
```

## Author

[Florian Frank](mailto:flori@ping.de)

## License

[MIT License](./LICENSE)
