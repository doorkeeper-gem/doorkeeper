module Term::ANSIColor
  # Term::ANSIColor version
  VERSION         = '1.11.3'
  VERSION_ARRAY   = VERSION.split('.').map(&:to_i) # :nodoc:
  VERSION_MAJOR   = VERSION_ARRAY[0] # :nodoc:
  VERSION_MINOR   = VERSION_ARRAY[1] # :nodoc:
  VERSION_BUILD   = VERSION_ARRAY[2] # :nodoc:
end
