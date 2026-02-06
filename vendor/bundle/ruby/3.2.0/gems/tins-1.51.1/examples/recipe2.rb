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
    deflect_start(Numeric, :method_missing, deflector)
    deflector2 = Deflector.new do |unit, id, name|
      ingredient = Ingredient.ingredient(name, unit)
      @ingredients << ingredient
    end
    deflect_start(Unit, :method_missing, deflector2)
    instance_exec(&block)
  ensure
    deflect_stop(Numeric, :method_missing) if deflect?(Numeric, :method_missing)
    deflect_stop(Unit, :method_missing) if deflect?(Unit, :method_missing)
  end

  attr_reader :ingredients

  def to_a
    @ingredients
  end
  alias to_ary to_a

  def to_s
    to_a * "\n"
  end
end

class RecipeInterpreter
  def recipe(&block)
    Recipe.new(&block)
  end
end

recipe_source = <<EOT
pancakes = recipe do
  2.cups.         flour
  2.5.teaspoons.  baking_powder
  0.5.teaspoon.   salt
  1.              egg
  1.5.cups.       milk
  2.tablespoons.  butter
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
