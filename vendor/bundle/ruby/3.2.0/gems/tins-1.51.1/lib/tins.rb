# Tins is a collection of useful Ruby utilities and tools that provide
# common functionality without requiring external dependencies. It's designed
# to be a lightweight, drop-in library that enhances Ruby's standard library
# with practical conveniences.
#
# @example Basic usage
#   require 'tins'
#
#   Tins::Once.only_once { puts "Only one instance" }
#
# @example Automatic class extensions
#   require 'tins/xt'
#
#   # Automatically extends core classes with useful methods
#   "foo".full? # => "foo"
#   "   ".full? # => nil
module Tins
  require 'tins/attempt'
  require 'tins/bijection'
  require 'tins/deep_dup'
  require 'tins/file_binary'
  require 'tins/find'
  require 'tins/generator'
  require 'tins/go'
  require 'tins/hash_symbolize_keys_recursive'
  require 'tins/hash_union'
  require 'tins/limited'
  require 'tins/lines_file'
  require 'tins/memoize'
  require 'tins/minimize'
  require 'tins/module_group'
  require 'tins/named_set'
  require 'tins/null'
  require 'tins/once'
  require 'tins/p'
  require 'tins/partial_application'
  require 'tins/range_plus'
  require 'tins/require_maybe'
  require 'tins/secure_write'
  require 'tins/string_camelize'
  require 'tins/string_underscore'
  require 'tins/string_version'
  require 'tins/string_named_placeholders'
  require 'tins/subhash'
  require 'tins/time_dummy'
  require 'tins/date_dummy'
  require 'tins/date_time_dummy'
  require 'tins/to_proc'
  require 'tins/version'
  require 'tins/write'
  require 'tins/extract_last_argument_options'
  require 'tins/responding'
  require 'tins/proc_compose'
  require 'tins/proc_prelude'
  require 'tins/concern'
  require 'tins/to'
  require 'tins/terminal'
  require 'tins/sexy_singleton'
  require 'tins/method_description'
  require 'tins/annotate'
  require 'tins/token'
  require 'tins/dslkit'
  require 'tins/case_predicate'
  require 'tins/implement'
  if defined? ::Encoding
    require 'tins/string_byte_order_mark'
  end
  require 'tins/complete'
  require 'tins/duration'
  require 'tins/unit'
  require 'tins/expose'
  require 'tins/temp_io'
  require 'tins/temp_io_enum'
  require 'tins/lru_cache'
  require 'tins/deprecate'
  require 'tins/hash_bfs'
end
require 'tins/alias'
