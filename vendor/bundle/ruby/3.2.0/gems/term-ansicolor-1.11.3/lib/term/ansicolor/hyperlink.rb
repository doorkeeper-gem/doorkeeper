require 'tins/terminal'

module Term
  module ANSIColor
    module Hyperlink
      def hyperlink(link, string = nil, id: nil, as_link: false)
        block_given? && string != nil && !respond_to?(:to_str) and
          raise ArgumentError,
          "Require either the string argument or a block argument"
        if link.nil?
          link = ''
        end
        if as_link && !link.empty?
          string ||= link
        end
        result = ''
        if Term::ANSIColor.coloring?
          result = "\e]8;#{"id=#{id}" unless id.nil?};".dup << link.to_str << "\e\\"
        end
        if block_given?
          result << yield.to_s
        elsif string.respond_to?(:to_str)
          result << string.to_str
        elsif respond_to?(:to_str)
          result << to_str
        else
          return result # only switch on
        end
        result << "\e]8;;\e\\" if Term::ANSIColor.coloring?
        result
      end
    end
  end
end
