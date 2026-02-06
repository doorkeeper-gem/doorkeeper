#!/usr/bin/env ruby

require 'tins'
$:.unshift 'examples'

include Tins::Deflect

puts "Example 1"
deflect(NilClass, :method_missing, Deflector.new { nil }) do
  begin
    p "foo".bar.baz
  rescue NoMethodError
    p "caught 1"
  end
  p nil.bar.baz
  t = Thread.new do
    begin
      p nil.bar.baz
    rescue NoMethodError
      p "caught 2"
    end
  end
  t.join if t.alive?
  p nil.bar.baz
end
begin
  p nil.bar.baz
rescue NoMethodError
  p "caught 3"
end

puts "-" * 70, "Example 2"
deflect_start(NilClass, :method_missing, Deflector.new { nil })
begin
  p "foo".bar.baz
rescue NoMethodError
  p "caught 1"
end
p nil.bar.baz
t = Thread.new do
  begin
    p nil.bar.baz
  rescue NoMethodError
    p "caught 2"
  end
end
t.join if t.alive?
p nil.bar.baz
deflect_stop(NilClass, :method_missing)
begin
  p nil.bar.baz
rescue NoMethodError
  p "caught 3"
end
