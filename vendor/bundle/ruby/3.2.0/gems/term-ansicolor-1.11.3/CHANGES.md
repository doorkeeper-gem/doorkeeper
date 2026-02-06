# Changes

## 2025-09-11 v1.11.3

- Added `fail_fast: true` configuration option
- Removed `ruby:3.0-alpine` from the images list
- Changed `s.date` from **2024-09-13** to **1980-01-02**
- Removed GitHub-specific files from ignore list
- Removed binary file detection configuration
- Updated Dockerfile and script to modernize dependencies and build process
- Removed obsolete `CHANGES` file and updated gemspec to exclude it
- Added `debug` and `all_images` as development dependencies
- Added `CHANGES.md` to the list of files in term-ansicolor.gemspec
- Used markdown for CHANGES file
- Updated gemspec
- Renamed license file
- Removed superfluous require statement that fixes issue #41

## 2024-08-04 v1.11.2

* Removed unnecessary `require` statement.

## 2024-08-01 v1.11.1

* **New Version Features**
  + The library now works with the `--enable-string-literal` option even on ancient Rubies.
  + A working URL has been added.
  + Development files are ignored when creating a package.

## 2024-08-01 v1.11.0

* **Significant Changes**:
  + Refactor `parse_row` method to use more concise syntax
  + Add memoized versions of `rgb_colors` for foreground and background colors, improving performance by reducing calculations required to find the nearest color for a given RGB value
  + Update term-ansicolor gemspec to use `gem_hadar` **1.16.1**
  + Use less map instead of other methods
  + Add new executable called `term_plasma` that draws a plasma effect on the console

## 2024-07-15 v1.10.4

* **Dependency Update**: 
  * Updated dependency on `mize` gem from `>= 0` to `~> 0.5`.

## 2024-07-15 v1.10.3

* **Display Resolution**: Doubled the display resolution.
* **Code Improvements**: Improved code and coverage.
* **Documentation**: Added documentation for `term_snow` command.
* **Math Operations**: Used clamp method.

## 2024-06-22 v1.10.2

* Increase compactibility with older Rubies:
  + Don't use new features
  + Allow testing on ancient Rubies

## 2024-06-22 v1.10.1

* **Color Treatment Change**: 
  * Treat all direct colors the same.
* **HTML Code Correction**:
  * Fix wrong HTML code.

## 2024-06-21 v1.10.0

* **New Features**
  + Add support for overline and underline with different types and colors.
  + Add some more codes for text.
* **Improvements**
  + Remove ordering hack for ruby < 1.9
  + Make grey color block more compact
* **Refactoring**
  + Remove and use global config

## 2024-06-18 v1.9.0

* **New Features**
  + Add true color support
  + Add `.utilsrc`
* **Bug Fixes**
  + Fix the wind (oops)
* **Miscellaneous Changes**
  + Require `test_helper`
  + Ignore `errors.lst`

## 2024-04-14 v1.8.0

* **New Features**
  + Added support for hyperlinks
  + Updated Ruby version to 3.3

## 2024-03-15 v1.7.2

* **New Version Features**
  + Use GitHub as homepage
  + Test compatibility with Ruby 3.2.0
  + Do not require Ruby, it's broken sometimes (development dependency removed)
  + Update CI/CD to use All Images instead of Travis

## 2019-01-18 v1.7.1

* Fix `term_display` command for never tins

## 2018-11-02 v1.7.0

* Add movement commands and `term_snow` executable

## 2017-04-13 v1.6.0

* Implement HSL colors and methods based on that code

## 2017-03-28 v1.5.0

* Change to Apache 2.0 license
* **New Features**
  + Implemented HSL (Hue, Saturation, Lightness) color support
  + Added several new methods for working with colors

## 2017-03-24 v1.4.1

* Correct triple html color support

## 2016-09-27 v1.4.0

* Extend colorized strings with Term::ANSIColor

## 2015-06-23 v1.3.2

* Fixed issues from previous 1.3.1 release

## 2015-06-17 v1.3.1

* This release was a bit premature, yanked it.

## 2014-02-06 v1.3.0

* Support bright and faint color names.

## 2013-05-30 v1.2.2

* No more fun and smileys, now you have to call `term_display` yourself.
* `term_display` can now display image URLs directly.

## 2013-05-24 v1.2.1

* Merge patch from Gavin Kistner <gavin@phrogz.net> to prevent warnings when
  running in -w mode.

## 2013-05-16 v1.2.0

* Add `term_mandel` and `term_display` executables.
* Implement configurable color metrics.
* Add gradient functionality for color attributes.

## 2013-04-18 v1.1.5

* Added `colortab` gem to RubyGems path.

## 2013-03-26 v1.1.4

* Easier access to color attributes via color(123) or approximate html colors
  like color('#336caf').

## 2013-03-26 v1.1.3

* Fix a bug where `respond_to` could overflow the stack.

## 2013-03-26 v1.1.2

* Change the API: color0 - color255 to color(:color0) -
color(:color255), and `on_color0` to `on_color(:color0)` -
`on_color(:color255)`; the previous way caused some
failures, sorry. On the plus side you can now do
color('#4a6ab4') and get the nearest terminal color to
this html color.

* Add colortab executable to display the 255 colors and
related HTML colors.

## 2013-03-08 v1.1.1

* Avoid possible conflicts with other people's attributes
  methods.
* Cache attributes globally, also fix caching for frozen
  strings.

## 2013-03-07 v1.1.0

* Cleanup documentation.
* Implement `color0` - `color255` and `on_color0` - `on_color255`
  methods for xterm256 colors.

## 2011-10-19 v1.0.8

* **Changes in Documentation**
  + Updated CHANGES file
  + Cleaned up documentation

## 2011-10-13 v1.0.7

* Merged patch by Mike Bethany <mikbe.tk@gmail.com> that adds high intensity
  colors and backgrounds.
* Fix problem caused by Ruby 1.9 implementing String#clear
  now, reported by Joe Fiorini <joe@joefiorini.com>.

## 2011-07-21 v1.0.6

* Use `gem_hadar` for Rakefile

## 2010-03-12 v1.0.5

* Added cdiff example as an executable.
* Disabled building of gemspec file.
* Made an decolor executable, that removes colors from an io stream.
* Match an additional way to clear the color in the `COLORED_REGEXP` for the
  uncolored method.

## 2009-07-23 v1.0.4

* Some cleanup.
* Build a gemspec file.

## 2007-10-05 v1.0.3

* Better documentation + some code clean up.
* Deleted autorequire from Rakefile.

## 2005-11-12 v1.0.2

* Added DESTDIR in front of install path to make repackaging easier. Thanks to
  Tilman Sauerbeck <tilman@code-monkey.de> for giving the hint.

## 2005-09-05 v1.0.1

* Fixed install bug in Rakefile, reported by Martin DeMello
  <martindemello@gmail.com>

## 2004-12-23 v1.0.0

* Added Term::ANSIColor.coloring[?=]? methods. Thanks, Thomas Husterer for the
  contribution.
* Minor cleanup of code.
* Documented visible methods in the module.

## 2004-09-28 v0.0.4

* First release on Rubyforge
* Supports Rubygems now

## 2003-10-09 v0.0.3

* Added uncolored method as suggested by Thomas Husterer <Thomas.Husterer@heidelberg.com>
* Added attribute methods with string arguments
* Deleted now unused files

## 2002-07-27 v0.0.2

* Minor Code Cleanup
* Added cdiff.rb

## 2002-06-12 v0.0.1

* Start
