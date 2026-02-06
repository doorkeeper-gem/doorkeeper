#!/usr/bin/env ruby

require 'tins/xt'
$:.unshift 'examples'
require 'recipe_common'

class Cup < Unit; end
class Teaspoon < Unit; end
class Tablespoon < Unit; end

class Flour < Ingredient; end
class Bakingpowder < Ingredient; end
class Salt < Ingredient; end
class Egg < Ingredient; end
class Milk < Ingredient; end
class Butter < Ingredient; end

class Recipe < Tins::BlankSlate.with(:respond_to?, :instance_exec, :inspect, /^deflect/)
  include Tins::Deflect

  def initialize(&block)
    @ingredients = []
    deflector = Deflector.new do |number, id, name|
      if unit = Unit.unit(name, number)
        unit
      else
        ingredient = Ingredient.ingredient(name, number)
        @ingredients << ingredient
      end
    end
    deflect(Numeric, :method_missing, deflector) do
      instance_exec(&block)
    end
  end

  attr_reader :ingredients

  def to_a
    @ingredients
  end
  alias to_ary to_a

  def to_s
    to_a * "\n"
  end
  alias inspect to_s

  def method_missing(name, *args)
    name = name.to_s.gsub(/_/, '').capitalize
    @ingredients << Object.const_get(name).new(*args)
  end
end

class RecipeInterpreter
  def recipe(&block)
    Recipe.new(&block)
  end
end

recipe_source = <<EOT
pancakes = recipe do
  flour         2.cups
  baking_powder 2.5.teaspoons
  salt          0.5.teaspoon
  egg           1
  milk          1.5.cups
  butter        2.tablespoons
end
EOT

pancakes = RecipeInterpreter.new.interpret(recipe_source)
puts pancakes

puts

def recipe(&block)
  Recipe.new(&block)
end

pancakes = eval recipe_source
puts pancakes
