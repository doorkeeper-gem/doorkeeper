#!/usr/bin/env ruby

load File.join(File.dirname(__FILE__), 'turing.rb')
include Turing

filename, *tapes = ARGV
machine_type =
  case ext = File.extname(filename)
  when '.stm'
    SingleTapeMachine
  when '.mtm'
    MultiTapeMachine
  else
    raise "unknown turing machine suffix: #{ext}, use .stm or .mtm"
  end
tm = machine_type.new(File.read(filename))
print tm.to_graphviz
