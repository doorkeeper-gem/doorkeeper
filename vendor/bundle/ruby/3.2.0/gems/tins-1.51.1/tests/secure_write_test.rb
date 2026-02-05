require 'test_helper'
require 'tempfile'
require 'pathname'

module Tins
  class TinsSecureWriteTest < Test::Unit::TestCase
    module A
      extend SecureWrite
    end

    def test_secure_write
      assert_equal 4, A.secure_write(fn = File.join(Dir.tmpdir, "A_file.#$$"), 'test')
      assert_equal 4, A.secure_write(fn = File.join(Dir.tmpdir, "A_file.#$$")) { |f| f.write('test') }
      assert_equal 'test', File.read(fn)
      assert_raise(ArgumentError) { A.secure_write }
    end

    def test_secure_write_with_pathname
      assert_equal 4, A.secure_write(fn = Pathname.new(Dir.tmpdir).join("A_file.#$$"), 'test')
      assert_equal 'test', File.read(fn)
    end

    module B
      extend Write
    end

    module C
      def self.write(*args)
        args
      end
      extend Write
    end

    class ::IO
      extend Write
    end

    def test_write
      assert_equal 4, B.write(fn = File.join(Dir.tmpdir, "B_file.#$$"), 'test')
      assert_equal 4, B.write(fn = File.join(Dir.tmpdir, "B_file.#$$")) { |f| f.write('test') }
      assert_equal 4, IO.write(fn = File.join(Dir.tmpdir, "IO_file.#$$"), 'test')
      assert_equal 'test', File.read(fn)
      result = C.write(fn = File.join(Dir.tmpdir, "C_file.#$$"), 'test')
      assert_equal [ fn, 'test' ], result
    end
  end
end
