# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Break Versioning](https://www.taoensso.com/break-versioning).

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

[Unreleased]: https://github.com/dry-rb/dry-inflector/compare/v1.3.1...main

## [1.3.1] - 2026-01-13

### Fixed

- Improve pluralization of "-um" vs "-ium" words. "Premium" is now pluralized correctly. (@hmaddocks in #60)

[1.3.1]: https://github.com/dry-rb/dry-inflector/compare/v1.3.0...v1.3.1

## [1.3.0] - 2026-01-09

### Changed

- Require Ruby 3.2 or later. (@alassek)
- Support characters with diacritics. (@cllns in #51)
- Improve performance of #singularize. (@sandbergja in #53)
- Remove redundant regexps for default inflections. (@hmaddocks in #59)

### Fixed

- Correctly handle pluralized aconyms in `#underscore`. For example, underscoring "CustomerAPIs" now gives "customer_apis". (@hmaddocks in #54)
- Correctly singularize "uses" and pluralize "use". (@hmaddocks in #55)
- Fix singularization of plurals ending in a vowel and "xes", such as "taxes" -> "tax". (@hmaddocks in #56)
- Fix pluralization of words ending in "ee", such as "fee" -> "fees". (@hmaddocks in #57)
- Fix singularizing of words like "leaves" and "thieves". (@hmaddocks in #58)
- Fix pluralization of words ending in "f" that should _not_ have their ending turn into "ves", e.g. "roof"->"roofs" and "chief"->"chiefs". (@hmaddocks in #59)
- Fix pluralization of "virus" into "viruses". (@hmaddocks in #59)

[1.3.0]: https://github.com/dry-rb/dry-inflector/compare/v1.2.0...v1.3.0

## [1.2.0] - 2025-01-04

### Changed

- Bumped required Ruby version to 3.1 (@flash-gordon)

[1.2.0]: https://github.com/dry-rb/dry-inflector/compare/v1.1.0...v1.2.0

## [1.1.0] - 2024-07-02

### Added

- Added "DB" as a default acronym. (@timriley in #49)

### Fixed

- Fix incorrect inflections on words separated by spaces, underscores or hyphens. (@parndt in #47)

[1.1.0]: https://github.com/dry-rb/dry-inflector/compare/v1.0.0...v1.1.0

## [1.0.0] - 2022-11-04

### Changed

- Bumped version to 1.0.0. (@solnic)

[1.0.0]: https://github.com/dry-rb/dry-inflector/compare/v0.3.0...v1.0.0

## [0.3.0] - 2022-07-12

### Added

- Add CSV as default acronym. (@waiting-for-dev in #43)

### Changed

- Extra dashes are now omitted when converting to camelcase. (@postmodern in #40)

[0.3.0]: https://github.com/dry-rb/dry-inflector/compare/v0.2.1...v0.3.0

## [0.2.1] - 2021-06-30

### Added

- Add default acronyms: API and CSRF. (@jodosha in #35)

### Fixed

- Fix singularizing -us suffix. (@cllns in #38)

[0.2.1]: https://github.com/dry-rb/dry-inflector/compare/v0.2.0...v0.2.1

## [0.2.0] - 2019-10-13

### Added

- Introduced `Dry::Inflector#camelize_upper` and `Dry::Inflector#camelize_lower`. `Dry::Inflector#camelize` is now an alias for `Dry::Inflector#camelize_upper`. (Abinoam P. Marques Jr. & Andrii Savchenko)

  ```ruby
  inflector.camelize_upper("data_mapper") # => "DataMapper"
  inflector.camelize_lower("data_mapper") # => "dataMapper"
  ``` 

### Fixed

- Fixed singularization rules for words like "alias" or "status". (ecnal)

[0.2.0]: https://github.com/dry-rb/dry-inflector/compare/v0.1.2...v0.2.0

## [0.1.2] - 2018-04-25

### Added

- Added support for acronyms. (Gustavo Caso & Nikita Shilnikov)

[0.1.2]: https://github.com/dry-rb/dry-inflector/compare/v0.1.1...v0.1.2

## [0.1.1] - 2017-11-18

### Fixed

- Ensure `Dry::Inflector#ordinalize` to work for all the numbers from 0 to 100. (Luca Guidi & Abinoam P. Marques Jr.)

[0.1.1]: https://github.com/dry-rb/dry-inflector/compare/v0.1.0...v0.1.1

## [0.1.0] - 2017-11-17

### Added

- Introduced `Dry::Inflector#pluralize`. (Luca Guidi)
- Introduced `Dry::Inflector#singularize`. (Luca Guidi)
- Introduced `Dry::Inflector#camelize`. (Luca Guidi)
- Introduced `Dry::Inflector#classify`. (Luca Guidi)
- Introduced `Dry::Inflector#tableize`. (Luca Guidi)
- Introduced `Dry::Inflector#dasherize`. (Luca Guidi)
- Introduced `Dry::Inflector#underscore`. (Luca Guidi)
- Introduced `Dry::Inflector#demodulize`. (Luca Guidi)
- Introduced `Dry::Inflector#humanize`. (Luca Guidi)
- Introduced `Dry::Inflector#ordinalize`. (Luca Guidi)
- Introduced `Dry::Inflector#foreign_key`. (Abinoam P. Marques Jr.)
- Introduced `Dry::Inflector#constantize`. (Abinoam P. Marques Jr.)
