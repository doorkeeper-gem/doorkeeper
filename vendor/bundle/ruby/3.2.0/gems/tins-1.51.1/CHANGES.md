# Changes

## 2026-01-14 v1.51.1

- Simplified `lru_cache` implementation to not need `NOT_EXIST`
- Updated `rubygems_version` from **4.0.2** to **4.0.3**
- Changed `gem_hadar` development dependency from "~> 2.10" to ">= 2.16.3"
- Updated Ruby image version from 4.0-rc-alpine to 4.0-alpine in CI pipeline
- Added comprehensive module documentation for `DSLKit` explaining its purpose
  and features
- Added `CHANGES.md` file to gem release process using `GemHadar`

## 2025-12-20 v1.51.0

- Added `readline` as a runtime dependency in both `Rakefile` and
  `tins.gemspec`
- The `readline` dependency version is set to `>= 0` in `tins.gemspec`
- The `readline` dependency is added to the `GemHadar` block in `Rakefile`

## 2025-12-19 v1.50.0

- Updated `gem_hadar` development dependency version to **2.10**
- Added `ruby:4.0-rc-alpine` image to the `images` section in `.all_images.yml`

## 2025-12-18 v1.49.0

- Updated `bundle update` command to `bundle update --all` in `.all_images.yml`
  to ensure all dependencies are updated recursively
- Added support for IEC binary prefixes with new `PREFIX_IEC_UC` constant and
  updated `prefixes` method to handle `:iec_uc` and `:iec_uppercase`
  identifiers
- Added corresponding test cases for IEC prefix mapping
- Added `:si_greek` alias for fractional prefixes (`m`, `µ`, `n`, etc.) in `PREFIX_F`
- Added `:si_uppercase` alias for SI uppercase prefixes (`K`, `M`, `G`, etc.) in `PREFIX_SI_UC`
- Updated `PREFIX_SI_UC` comment to clarify these are based on **1000**-step increments, not 1024
- Enhanced `prefixes` method to support new aliases while maintaining backward compatibility
- Added comprehensive tests for new aliases in `Tins::UnitTest`
- Updated `s.rubygems_version` from **3.7.2** to **4.0.2** in gemspec

## 2025-12-05 v1.48.0

- Added `Tins::Token.analyze` class method to calculate bit strength
- Moved bit calculation logic from `initialize` to `analyze` method for reuse
- Implemented bit strength calculation using formula: `length ×
  log₂(alphabet_size)`
- Added comprehensive tests for the `analyze` method with various alphabets
- Support both token string and length-based analysis
- Implemented proper error handling for required parameters
- Updated `initialize` method to use the new `analyze` method
- Test cases verify bit strength for **BASE16**, **BASE64**, and **BASE32**
  alphabets
- Method returns integer bit strength for cryptographic token analysis

## 2025-11-14 v1.47.0

- Tins::GO
    - Renamed `EnumerableExtension` module to `ArrayExtension` throughout the
      codebase
    - Updated method calls from `<<` to `push` for consistency with
      `ArrayExtension`
    - Modified `to_a` method implementation to return `@arguments` directly
    - Updated test assertions to expect `ArrayExtension` instead of
      `EnumerableExtension`
    - Changed documentation comments to reflect the new `ArrayExtension` name
    - Updated type checking from `EnumerableExtension` to `ArrayExtension` in
      conditional logic

## 2025-11-10 v1.46.0

- Updated `s.rubygems_version` from **3.6.9** to **3.7.2** in gemspec
- In Tins::GO
    - Extended string defaults with `EnumerableExtension` transformation
    - Modified `v.transform_values!` to check and extend strings that aren't already `EnumerableExtension`
    - Applied `w << w` to properly initialize the extension on default strings
    - Updated tests to verify `EnumerableExtension` instances for both `v` and `w` options
    - Set default value for `?w` option to **'baz'** in test cases
    - Maintained backward compatibility while normalizing string handling
    - Ensured consistent behavior between ARGV strings and default strings

## 2025-10-16 v1.45.0

- Added `patch` alias for `build` and `build=` methods to align with SemVer terminology
- Updated `LEVELS` mapping to support `:patch` as alias for `:build` index
- Added `patch` and `patch=` aliases using the `alias` method
- Added tests for `patch` getter and setter functionality
- Updated `gem_hadar` development dependency from version **2.5** to **2.8**
- Added `openssl-dev` to Docker build dependencies
- Added `github_workflows` configuration to `Rakefile` for `static.yml` workflow
- Removed `.byebug_history` from `.gitignore` file
- Removed `.byebug_history` from ignore list in `Rakefile`
- Removed duplicate `mize` entry from code indexer configuration

## 2025-09-13 v1.44.1

- Updated documentation link in README.md to point to GitHub.io instead of
  RubyDoc.info
- Added graceful handling for missing `gem_hadar/simplecov` gem by wrapping
  require and start in begin/rescue block to catch `LoadError`
- Modified gem packaging to include all files in `.github` and `.contexts` directories using `FileList` for dynamic inclusion
- Created `static.yml` file

## 2025-09-12 v1.44.0

### Major Changes

- **Ruby Version Requirement**: Updated minimum Ruby version requirement to 3.1
- **Dependency Modernization**: Replaced deprecated `Tins::Memoize` module
  implementation with `mize` gem for memoization functionality
- **Documentation Overhaul**: Comprehensive YARD documentation added across all
  modules with examples and parameter descriptions
- **README Enhancement**: Improved README.md with better documentation,
  examples, and usage instructions

## 2025-09-05 v1.43.0

- Added new `dsl_lazy_accessor` method that creates lazy-loaded accessors with
  support for default blocks and dynamic block assignment
- Removed support for Ruby versions **3.1** and **3.0** from image definitions

## 2025-08-19 v1.42.0

- Improved core class extension safety by using `respond_to?` checks to avoid
  overriding existing methods such as `deep_dup`, `camelize`, and `underscore`
- Simplified GitHub directory ignore patterns in `Rakefile` by removing
  recursive glob pattern for `.github` directory and directly specifying it as
  a single entry
- Added documentation context files and YARD cheatsheet, including `.contexts/`
  directory with code comment examples and updated `Rakefile` and
  `tins.gemspec` to include context files and `context_spook` dependency

## 2025-08-18 v1.41.0

- Added new `named_placeholders_interpolate` method for template substitution
- Method supports both static and dynamic default values via Proc
- Maintains backward compatibility with existing `named_placeholders_assign` method
- Includes comprehensive tests for all functionality and error handling
- Uses `named_placeholders_assign` internally for consistent implementation

## 2025-08-18 v1.40.0

- Added `Tins::StringNamedPlaceholders` module with `named_placeholders` and
  `named_placeholders_assign` methods for string template substitution
- Implemented support for both static and dynamic default values using Proc
  objects
- Extended `String` class with `tins/xt/string` to include the new named
  placeholders functionality
- Enhanced test coverage with comprehensive tests for all named placeholders
  functionality including error handling and duplicate placeholder management
- Replaced manual SimpleCov setup with `GemHadar::SimpleCov.start` in test
  helper

## 2025-07-30 v1.39.1

- Updated `gem_hadar` development dependency to version **1.22**
- Bumped version from '1.39.0' to '1.39.1' in lib/tins/version.rb
- Updated `s.version` in tins.gemspec from "1.39.0" to "1.39.1"
- Updated stub version in tins.gemspec from **1.39.0** to **1.39.1**

## 2025-07-30 v1.39.0

- Updated `VERSION` constant in `lib/tins/version.rb` from **1.38.0** to **1.39.0**
- Updated gem stub and version in `tins.gemspec`
- Updated `s.rubygems_version` from **3.6.2** to **3.6.9**
- Updated `s.add_development_dependency :gem_hadar` from ~> **1.19** to ~> **1.21**
- Added support for thread naming in `Limited` class
  - Added `name` parameter to `Limited#initialize`
  - Set `@name` attribute when provided
  - Set executor name with `@name` if available
  - Updated tests to use named threads
- Removed `binary` option from discover block in `.utilsrc`

## 2025-01-04 v1.38.0

* Improved Tins::Limited concurrency handling:
  * Added `execute` method for task submission with a block
  * Changed `process` method to manage thread execution and queue management
  * Introduced `stop` method to signal processing termination
  * Modified test cases in `limited_test.rb` to accommodate new functionality
  * Added `ensure` clause to decrement counter and signal continuation after
    block execution
* Added support for Ruby **3.4** Alpine image:
  * Updated `.all_images.yml` to include Ruby **3.4**-alpine environment
  * Added `ruby:3.4-alpine` to the list of supported images
  * Now uses **3.4** instead of **3.3**, **3.2**, and **3.1** for ruby versions

## 2024-12-13 v1.37.1

* Renamed `ZERO` and `BINARY` constants to `ZERO_RE` and `BINARY_RE` to avoid
  collisions with Logger/File constants.

## 2024-10-19 v1.37.0

* Add support for module prepended blocks in **Tins::Concern**:
  * Added `prepend_features` method to Tins concern
  * Updated ConcernTest to test prepend feature
  * Raise StandardError for duplicate block definitions for included and 
    prepended blocks
* Added `class_methods` method to Tins concern:
  * Added `class_methods` method to lib/tins/concern.rb
    - Creates or retrieves ClassMethods module for defining class-level methods
  * Updated tests in `tests/concern_test.rb`
    - Added test for new `baz1` and `baz2` methods
      + Tested availability of `bar`, `baz1`, and `baz2` methods on A

## 2024-10-11 v1.36.1

* Fixed a typo in the code

## 2024-10-11 v1.36.0

### Significant Changes

* Refactor bfs method in `hash_bfs.rb`:
  + Rename `include_nodes` variable to `visit_internal`
  + Update test cases in `hash_bfs_test.rb` to use new method signature
  + Update method signature and docstring to reflect new behavior
* Update hash conversion logic:
  + Rename method parameter from `v` to `object`
  + Use `object` instead of `v` consistently throughout the method
  + Add documentation for new method name and behavior

## 2024-10-10 v1.35.0

### New Features
* Implemented breadth-first search in hashes using the `Tins::HashBFS` module.
  + Added tests for the `Tins::HashBFS` module.

### Refactoring and Cleanup
* Reformatted code.
* Removed TODO note from the `TODO` file.
* Cleaned up test requirements:
  - Added `require 'tins'` to `tests/test_helper.rb`.
  - Removed unnecessary `require 'tins'` lines from test files.
* Refactored BASE16 constants and alphabet:
  + Added `BASE16_LOWERCASE_ALPHABET` constant.
  + Added `BASE16_UPPERCASE_ALPHABET` constant.

### Tool Updates
* Updated bundler command to use full index:
  - Added `--full-index` flag to `bundle install`.
  - Replaced `bundle update` with `bundle install --full-index`.

## 2024-09-30 v1.34.0

* **Secure write functionality updated**
  + Added support for `Pathname` objects in `secure_write`
  + Updated `File.new` call to use `to_s` method on filename
  + New test case added for `secure_write` with `Pathname` object
* **Refactor version comparisons in various modules**
  + Added `Tins::StringVersion.compare` method to compare Ruby versions with operators.
  + Replaced direct version comparisons with `compare` method in multiple modules.
* **Deprecate deep_const_get and const_defined_in? methods**
  + Add deprecation notice for `const_defined_in?` for ruby >= 1.8
  + Add deprecation notice for `deep_const_get` method with a new method name `const_get` for ruby >= 2.0
* **Refactor deprecation logic and tests**
  + Update `Tins::Deprecate#deprecate` method to allow for optional `new_method` parameter.
  + Modify `tests/deprecate_test.rb` to test deprecated methods with and without messages.
* **Prepare count_by method for deprecation**
  + Suggest using `count` with block instead in newer Rubies
* **Prepare uniq_by / uniq_by! method for deprecation**
  + Suggest using `uniq` / `uniq!` with block instead in newer Rubies

## 2024-04-17 v1.33.0

* **Changes for Ruby 3.3 and 3.4**
  + Added support for Ruby **3.3**
  + Added dependency on `bigdecimal` for upcoming Ruby **3.4**
* **Other Changes**
  + Halting once is enough
  + Added ruby **3.2**, removed some older ones
  + Added test process convenience method

## 2022-11-21 v1.32.1

* Removed mutex for finalizer, allowing Ruby to handle cleanup instead.
* Significant changes:
  + Removed `mutex` variable
  + Updated code to rely on Ruby's built-in finalization mechanism

## 2022-11-17 v1.32.0

* **attempt** method now supports passing of previously caught exception into
  the called block to let the handling behaviour depend on it.
* Some smaller changes to make debugging on multiple Ruby releases, easier via
  all_images.
* Enable fast failing mode
* Add convenience method to create `Tins::StringVersion` objects.
* Pass previous exception to attempt block ...
  ... to allow reacting to it, logging it etc.
* Remove additional groups
* Use debug instead of byebug for development
* Ignore more hidden files in the package
* Update Ruby version to **3.1**
