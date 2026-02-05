# Term::ANSIColor - ANSI escape sequences in Ruby

## Description

This library can be used to color/decolor strings using ANSI escape sequences.

## Installation

Use rubygems to install the gem:

```
# gem install term-ansicolor
```

## Download

The homepage of this library is located at

* https://github.com/flori/term-ansicolor

## Examples

The following executables are provided with Term::ANSIColor:

* `term_cdiff`: colors a diff patch
* `term_colortab`: Displays a table of the 256 terminal colors with their indices and
  nearest html equivalents.
* `term_display`: displays a ppm3 or ppm6 image file in the terminal. If the netpbm
  programs are installed it can handle a lot of other image file formats.
* `term_decolor`: decolors any text file that was colored with ANSI escape sequences
* `term_mandel`: displays the mandelbrot set in the terminal
* `term_plasma`: draws a plasma effect on the console, possibly animated and
  refreshed every `-n seconds`.
* `term_snow`: displays falling snow in the terminal using ANSI movement
  sequences.


Additionally the file examples/example.rb in the source/gem-distribution shows
how this library can be used.

## Author

Florian Frank mailto:flori@ping.de

## License

This software is licensed under the Apache 2.0 license.
