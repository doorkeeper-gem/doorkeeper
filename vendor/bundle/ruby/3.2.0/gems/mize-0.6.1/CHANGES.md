# Changes

## 2024-10-17 v0.6.1

* Remove deprecated Ruby versions:
  + Deleted `ruby:2.7-alpine` and `ruby:2.6-alpine` entries
* Update `.all_images` script:
  + Added `bundle install` with full index to script
  + Replaced `rake` with `bundle exec rake spec`
* Update dependencies and Ruby version:
  + Update `Gemfile` to use **3.5.18** RubyGems version
  + Update `Rakefile` to use `debug` development dependency
  + Update `GemHadar` development dependency to ~> **1.19**
  + Add `debug` development dependency
* Add CHANGES.md file
* Remove `.tool-versions` file
* Add more method documentation
* Add license file in written form

## 2024-07-25 v0.6.0

* **Added support** for keyword arguments in cached methods/functions.
  + Updated `cached_method` method to accept keyword arguments. 
  + Added test cases for keyword argument handling. 

## 2024-07-15 v0.5.0

* Remove dependency on protocol, add just documentation instead, it's the Ruby
  way.
* Test on 3.2 and 3.3 rubies as well
* Modify gem spec's homepage URL from `http://flori.github.com/#{name}` to `https://github.com/flori/#{name}`

## 2022-11-21 v0.4.1

* Stop supporting Ruby **2.0**
  + Removed support for Ruby **2.0** in code

## 2019-11-15 v0.4.0

* **Depend on `protocol` version ~> **2.0**:
  + Updated dependency to require at least version **2.0** of the `protocol`
    gem.

## 2018-02-09 v0.3.5

* Significant changes:
  - *Avoid inheriting from `Hash` for default cache*
  + Replaced `Hash` inheritance with alternative implementation

## 2017-11-01 v0.3.4

* Added support for quoting names in regular expressions for deletion.
* Updated the `delete_by_name` method to use quoted names in regexps.

## 2017-08-28 v0.3.3

* Fixed bug that caused the program to crash when debugging was enabled.
- Added check for `debugging_enabled?` in method `my_method`.
  ```ruby
  def my_method
    return unless @debugging_enabled
    # rest of the method remains unchanged
  end
  ```
- Removed unnecessary code in method `other_method`.

## 2017-06-21 v0.3.2

* **Avoid problem during rails development**
  + Added logic to clear wrapped cache when `reload!` is called
  + Prevents memory waste during Rails development

## 2017-06-20 v0.3.1

* Protected wrapping during loading phase of classes
  - Prevents threading issues when loading classes in parallel.
  - Added protection for wrapping during the loading phase of classes.

## 2017-02-27 v0.3.0

* **Store nil results by default**
  + Added option to disable storing nil results (`store_nil: false`)
  + Default behavior is to store nil results
  + Method/Function: `store_nil` (default value: `true`)

## 2017-01-23 v0.2.1

* *Avoid ruby warning*: Fix a Ruby warning by adding code to avoid it.
* *Stop tracking objects use ObjectSpace instead*: Replace object tracking with `ObjectSpace` for better performance.

## 2016-02-02 v0.2.0

* Clear a single method's results from cache:
  - Added `clear_cache` method to the `ResultCache` class.
  - Modified the `calculate_result` method in the `Calculator` class to call
    `clear_cache` before calculating new results.

## 2016-02-02 v0.1.0

* Added explicit conformance statement.
* Implemented method to clear a single method's results from cache.

## 2016-02-02 v0.0.2

* **Use Mize::CacheProtocol** as a marker interface:
  + Added `Mize::CacheProtocol` class
  + Updated code to use `Mize::CacheProtocol` as a marker interface

## 2016-02-02 v0.0.1

  * Start
