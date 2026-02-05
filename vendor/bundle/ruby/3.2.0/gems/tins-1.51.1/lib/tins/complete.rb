require 'readline'

module Tins
  # A module that provides completion functionality for objects.
  module Complete
    module_function

    @@sync = Sync.new

    # The complete method reads a line of input from the user with optional
    # prompt and history support.
    #
    # @param prompt [ String ] the prompt string to display to the user
    # @param add_hist [ Boolean ] whether to add the input to the command
    # history
    #
    # @yield [ String ] the completion procedure to use for tab completion
    #
    # @return [ String ] the line of input entered by the user
    #
    # @example Prompt with easy tab completion
    #   complete(prompt: 'Pick a ruby file! ') {
    #     Dir['**/*.rb'].grep(/#{it}/)
    #   }.then { '%u lines' % File.new(it).each_line.count }
    def complete(prompt: '', add_hist: false, &block)
      @@sync.synchronize do
        Readline.completion_proc = block
        Readline.input           = STDIN
        Readline.output          = STDOUT
        Readline.readline(prompt, add_hist)
      end
    end
  end
end
