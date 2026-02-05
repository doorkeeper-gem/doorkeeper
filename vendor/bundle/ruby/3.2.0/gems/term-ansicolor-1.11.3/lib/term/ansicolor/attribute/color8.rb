module Term
  module ANSIColor
    class Attribute
      class Color8
        Attribute.set :black,   30, direct: '#000000'
        Attribute.set :red,     31, direct: '#800000'
        Attribute.set :green,   32, direct: '#008000'
        Attribute.set :yellow,  33, direct: '#808000'
        Attribute.set :blue,    34, direct: '#000080'
        Attribute.set :magenta, 35, direct: '#800080'
        Attribute.set :cyan,    36, direct: '#008080'
        Attribute.set :white,   37, direct: '#c0c0c0'

        Attribute.set :on_black,   40, direct: '#000000'
        Attribute.set :on_red,     41, direct: '#800000'
        Attribute.set :on_green,   42, direct: '#008000'
        Attribute.set :on_yellow,  43, direct: '#808000'
        Attribute.set :on_blue,    44, direct: '#000080'
        Attribute.set :on_magenta, 45, direct: '#800080'
        Attribute.set :on_cyan,    46, direct: '#008080'
        Attribute.set :on_white,   47, direct: '#808080'
      end
    end
  end
end
