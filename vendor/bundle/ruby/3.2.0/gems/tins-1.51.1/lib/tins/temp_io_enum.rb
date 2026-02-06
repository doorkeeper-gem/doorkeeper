require 'tins/temp_io'

module Tins
  module TempIO
    # A streaming enumerator that reads file content in configurable chunks
    # from temporary files.
    #
    # This class provides an efficient way to process large files without
    # loading them entirely into memory. It creates a temporary file from the
    # provided content generator and yields data in fixed-size chunks.
    class Enum < Enumerator
      include Tins::TempIO

      # This method creates an enumerator that yields chunks of data from a
      # temporary file generated from the provided content proc. It's designed
      # for streaming large files efficiently (to a user's web browser for
      # example) by reading them in fixed-size chunks rather than loading
      # everything into memory.
      #
      # @param chunk_size [ Integer ] the size of each chunk to read from the
      # file
      # @param filename [ String, nil ] optional filename to associate with the
      # enumerator
      # @param content_proc [ Proc ] a block that generates file content
      # @return [ Enumerator ] an enumerator that yields file chunks,
      # eventually having #filename defined as the parameter filename.
      def initialize(chunk_size: 2 ** 16, filename: nil, &content_proc)
        content_proc or raise ArgumentError, 'need a content proc as block argument'
        super() do |y|
          temp_io(name: 'some-stream', content: content_proc) do |file|
            until file.eof?
              y.yield file.read(chunk_size)
            end
          end
        end.tap do |enum|
          if filename
            enum.define_singleton_method(:filename) do
              filename
            end
          end
        end
      end
    end
  end
end
