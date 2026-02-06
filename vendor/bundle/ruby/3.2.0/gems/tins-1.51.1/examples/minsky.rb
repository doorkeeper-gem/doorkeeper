#!/usr/bin/env ruby

require 'tins'

# A small Minsky (register) machine
module Minsky
  class InterpreterError < StandardError; end

  class ::Proc
    attr_accessor :interpreter

    attr_accessor :name

    def execute
      interpreter.display_registers(self)
      call
    end
  end

  class Registers
    def initialize
      @registers = Hash.new(0)
    end

    def [](name)
      @registers[name]
    end

    def []=(name, value)
      @registers[name] = value
    end

    def to_s
      "[" + @registers.sort_by { |r,| r.to_s }.map { |r,v| "#{r}: #{v}" } *
      "|" + "]"
    end

    def method_missing(name, value)
      name = name.to_s
      if name[-1] == ?=
        name = name[0..-2].intern
        value >= 0 or raise InterpreterError,
          "only non-negative numbers can be stored in register #{name}"
        @registers[name] = value
      else
        super
      end
    end
  end

  class Interpreter
    include Tins::Interpreter
    extend Tins::ConstantMaker

    def initialize(source)
      @source = source
      @labels = []
      @registers = Registers.new
    end

    attr_writer :stepping

    def run
      interpret_with_binding(@source, binding)
      cont = @labels.first
      while cont
        cont = cont.execute
      end
      self
    end

    def display_registers(label)
      @format ||= "%#{@labels.map { |l| l.name.to_s.size }.max}s"
      STDOUT.puts "#{@format % label.name}: #{@registers}"
      if @stepping
        STDOUT.print "? "
        STDOUT.flush
        STDIN.gets
      end
    end

    private

    def label(name, &block)
      @labels.find { |l| l.name == name }  and
        raise InterpreterError, "label named '#{name}' was already defined"
      block.interpreter, block.name = self, name
      @labels << block
    end

    def register_fetch(register)
      @registers[register]
    end

    def register_decrement(register)
      @registers[register] -= 1
    end

    def register_increment(register)
      @registers[register] += 1
    end

    def label_fetch(name)
      label = @labels.find { |l| l.name == name  }
      label or raise InterpreterError, "label named '#{name}' was not defined"
    end

    def increment(register, label)
      label = label_fetch label
      register_increment(register)
      label
    end

    def decrement(register, zero_label, else_label)
      register_value = register_fetch register
      zero_label = label_fetch zero_label
      else_label = label_fetch else_label
      if register_value.zero?
        zero_label
      else
        register_decrement(register)
        else_label
      end
    end

    def register
      @registers
    end

    def halt
      STDOUT.puts " *** machine halted"
      nil
    end
  end
end

if $0 == __FILE__
  if ARGV.empty?
    Minsky::Interpreter.new(STDIN.read).run
  else
    interpreter = Minsky::Interpreter.new(File.read(ARGV.shift))
    interpreter.stepping = !ARGV.empty?
    interpreter.run
  end
end
