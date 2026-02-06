# Sync

A module that provides a two-phase lock with a counter.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sync'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sync

## Usage

### Sync_m, Synchronizer_m

```
obj.extend(Sync_m)
```

or

```
class Foo
    include Sync_m
    :
end
```

```
Sync_m#sync_mode
Sync_m#sync_locked?, locked?
Sync_m#sync_shared?, shared?
Sync_m#sync_exclusive?, sync_exclusive?
Sync_m#sync_try_lock, try_lock
Sync_m#sync_lock, lock
Sync_m#sync_unlock, unlock
```

### Sync, Synchronizer:

```
sync = Sync.new
```

```
Sync#mode
Sync#locked?
Sync#shared?
Sync#exclusive?
Sync#try_lock(mode) -- mode = :EX, :SH, :UN
Sync#lock(mode)     -- mode = :EX, :SH, :UN
Sync#unlock
Sync#synchronize(mode) {...}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ruby/sync.

## License

The gem is available as open source under the terms of the [2-Clause BSD License](https://opensource.org/licenses/BSD-2-Clause).
