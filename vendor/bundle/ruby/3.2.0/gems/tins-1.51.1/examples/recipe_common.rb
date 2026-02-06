class Ingredient
  class << self
    def inherited(klass)
      ingredients << klass
    end

    attr_accessor :ingredients

    def ingredient(name, amount)
      name = name.to_s.gsub(/_/, '').capitalize
      if klass = ingredients.find { |n| n.to_s == name }
        klass.new(amount)
      else
        raise "unknown ingredient #{name}"
      end
    end
  end
  self.ingredients = []

  def initialize(amount = 1)
    @amount = amount
  end

  def name
    self.class.name.downcase
  end

  attr_reader :amount

  def to_s
    "#@amount #{name}"
  end
end

class Unit
  class << self
    def inherited(klass)
      units << klass
    end

    attr_accessor :units

    def unit(name, amount)
      name = name.to_s.gsub(/s$/, '').capitalize
      if klass = units.find { |n| n.to_s == name }
        klass.new(amount)
      end
    end
  end
  self.units = []

  def initialize(n = 1)
    @n = n
  end

  def name
    self.class.name.downcase
  end

  attr_reader :n

  def to_s
    "#@n #{name}#{@n > 1 ? 's' : ''}"
  end
end
