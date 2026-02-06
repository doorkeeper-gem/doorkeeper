require 'tmpdir'

module Tins
  # A module for creating temporary files and handling their contents securely.
  module TempIO
    # Creates a temporary file with the given content and yields it to a block.
    #
    # @param content [String, #call] the content to write to the temporary file
    # @param name [String, Symbol] the base name for the temporary file
    # @yield [io] yields the temporary file handle to the given block
    # @return [Object] the return value of the block
    def temp_io(content: nil, name: __method__)
      content.nil? and raise ArgumentError, "missing keyword: content"
      name = File.basename(name.to_s)
      Dir.mktmpdir do |dir|
        name = File.join(dir, name)
        File.open(name, 'w+b') do |io|
          if content.respond_to?(:call)
            if content.respond_to?(:arity) && content.arity == 1
              content.call(io)
            else
              io.write content.call
            end
          else
            io.write content
          end
          io.rewind
          yield io
        end
      end
    end
  end
end
