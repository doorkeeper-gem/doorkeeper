require 'term/ansicolor/attribute/underline'

module Term
  module ANSIColor
    class Attribute
      class Text
        Attribute.set :clear,            0           # String#clear already used in String
        Attribute.set :reset,            0           # synonym for :clear
        Attribute.set :bold,             1
        Attribute.set :dark,             2
        Attribute.set :faint,            2
        Attribute.set :italic,           3           # not widely implemented
        Attribute.set :blink,            5
        Attribute.set :rapid_blink,      6           # not widely implemented
        Attribute.set :reverse,          7           # String#reverse already used in String
        Attribute.set :negative,         7           # synonym for :reverse
        Attribute.set :concealed,        8
        Attribute.set :conceal,          8           # synonym for :concealed
        Attribute.set :strikethrough,    9           # not widely implemented
        Attribute.set :overline,         53

        include Term::ANSIColor::Attribute::Underline
      end
    end
  end
end
