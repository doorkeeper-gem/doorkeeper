module Term
  module ANSIColor
    class Attribute
      class Color256
        Attribute.set :color0, 0, html: '#000000'
        Attribute.set :color1, 1, html: '#800000'
        Attribute.set :color2, 2, html: '#008000'
        Attribute.set :color3, 3, html: '#808000'
        Attribute.set :color4, 4, html: '#000080'
        Attribute.set :color5, 5, html: '#800080'
        Attribute.set :color6, 6, html: '#008080'
        Attribute.set :color7, 7, html: '#c0c0c0'

        Attribute.set :color8, 8, html: '#808080'
        Attribute.set :color9, 9, html: '#ff0000'
        Attribute.set :color10, 10, html: '#00ff00'
        Attribute.set :color11, 11, html: '#ffff00'
        Attribute.set :color12, 12, html: '#0000ff'
        Attribute.set :color13, 13, html: '#ff00ff'
        Attribute.set :color14, 14, html: '#00ffff'
        Attribute.set :color15, 15, html: '#ffffff'

        steps = [ 0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff ]

        for i in 16..231
          red, green, blue = (i - 16).to_s(6).rjust(3, '0').each_char.map { |c| steps[c.to_i] }
          Attribute.set "color#{i}", i, red: red, green: green, blue: blue
        end

        grey = 8
        for i in 232..255
          Attribute.set "color#{i}", i, red: grey, green: grey, blue: grey
          grey += 10
        end

        Attribute.set :on_color0, 0, html: '#000000', background: true
        Attribute.set :on_color1, 1, html: '#800000', background: true
        Attribute.set :on_color2, 2, html: '#808000', background: true
        Attribute.set :on_color3, 3, html: '#808000', background: true
        Attribute.set :on_color4, 4, html: '#000080', background: true
        Attribute.set :on_color5, 5, html: '#800080', background: true
        Attribute.set :on_color6, 6, html: '#008080', background: true
        Attribute.set :on_color7, 7, html: '#c0c0c0', background: true

        Attribute.set :on_color8, 8, html: '#808080', background: true
        Attribute.set :on_color9, 9, html: '#ff0000', background: true
        Attribute.set :on_color10, 10, html: '#00ff00', background: true
        Attribute.set :on_color11, 11, html: '#ffff00', background: true
        Attribute.set :on_color12, 12, html: '#0000ff', background: true
        Attribute.set :on_color13, 13, html: '#ff00ff', background: true
        Attribute.set :on_color14, 14, html: '#00ffff', background: true
        Attribute.set :on_color15, 15, html: '#ffffff', background: true

        steps = [ 0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff ]

        for i in 16..231
          red, green, blue = (i - 16).to_s(6).rjust(3, '0').each_char.map { |c| steps[c.to_i] }
          Attribute.set "on_color#{i}", i,
            red: red, green: green, blue: blue, background: true
        end

        grey = 8
        for i in 232..255
          Attribute.set "on_color#{i}", i,
            red: grey, green: grey, blue: grey, background: true
          grey += 10
        end
      end
    end
  end
end
