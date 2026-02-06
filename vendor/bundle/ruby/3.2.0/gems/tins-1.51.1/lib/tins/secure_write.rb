module Tins
  # A module that provides secure file writing capabilities.
  #
  # This module extends objects with a method to write data to files in a way
  # that ensures atomicity and prevents partial writes, making it safer for
  # concurrent access.
  module SecureWrite
    # Write to a file atomically by creating a temporary file and renaming it.
    # This ensures that readers will either see the complete old content or
    # the complete new content, never partial writes.
    #
    # @param filename [String, #to_s] The target filename
    # @param content [String, nil] The content to write (optional)
    # @param mode [String] File open mode (default: 'w')
    # @yield [File] If a block is given, yields the temporary file handle
    # @return [Integer] The number of bytes written
    # @raise [ArgumentError] If neither content nor block is provided
    #
    # @example With content
    #   File.secure_write('config.json', '{"timeout": 30}')
    #
    # @example With block
    #   File.secure_write('output.txt') do |f|
    #     f.write("Hello, World!")
    #   end
    def secure_write(filename, content = nil, mode = 'w')
      temp = File.new(filename.to_s + ".tmp.#$$.#{Time.now.to_f}", mode)
      if content.nil? and block_given?
        yield temp
      elsif !content.nil?
        temp.write content
      else
        raise ArgumentError, "either content or block argument required"
      end
      temp.fsync
      size = temp.stat.size
      temp.close
      File.rename temp.path, filename
      size
    ensure
      if temp
        temp.closed? or temp.close
        File.file?(temp.path) and File.unlink temp.path
      end
    end
  end
end
