module Tins
  # Provides a simple way to remove common leading whitespace from multi-line
  # strings, mostly for to(<<-EOT), if require "tins/xt/to". Today you would
  # probably use <<~EOT in this case.
  #
  # Example usage:
  #   doc = to(<<-EOT)
  #     hello
  #       world
  #     end
  #   EOT
  #   # => "hello\n  world\nend"
  module To
    # Remove common leading whitespace from multi-line strings
    #
    # @param string [String] The multi-line string to deindent
    # @return [String] String with common leading whitespace removed
    def to(string)
      shift_width = (string[/\A\s*/]).size
      string.gsub(/^[^\S\n]{0,#{shift_width}}/, '')
    end
  end
end
