require "objspace"
require "uri"
require_relative "../lib/mustermann/ast/translator"

translator = Mustermann::AST::Translator.new
translator.escape("foo")

h1 = ObjectSpace.each_object.inject(Hash.new 0) { |h, o| h[o.class] += 1; h }

100.times do
  translator.escape("foo")
end

h2 = ObjectSpace.each_object.inject(Hash.new 0) { |h, o| h[o.class] += 1; h }

raise if (h2[URI::RFC2396_Parser] - h1[URI::RFC2396_Parser] != 0)
