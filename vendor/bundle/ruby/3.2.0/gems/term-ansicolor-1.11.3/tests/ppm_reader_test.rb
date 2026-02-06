require 'test_helper'
require 'digest/md5'

class PPMReaderTest < Test::Unit::TestCase
  include Term::ANSIColor

  def test_loading_ppm6
    File.open(example_path('lambda-red.ppm')) do |ppm6|
      ppm_reader = PPMReader.new(ppm6)
      assert_equal '2035155a4242e498f4852ae8425dac6b',
        Digest::MD5.hexdigest(ppm_reader.to_s)
    end
  end

  def test_loading_ppm3
    File.open(example_path('lambda-red-plain.ppm')) do |ppm6|
      ppm_reader = PPMReader.new(ppm6)
      assert_equal '2035155a4242e498f4852ae8425dac6b',
        Digest::MD5.hexdigest(ppm_reader.to_s)
    end
  end

  def test_rendering_ppm_without_gray
    File.open(example_path('lambda-red.ppm')) do |ppm6|
      ppm_reader = PPMReader.new(ppm6, :gray => false)
      assert_equal '0653f40e42a87fc480e09db1c58f71ba',
        Digest::MD5.hexdigest(ppm_reader.to_s)
    end
  end

  def test_rendering_ppm_with_true_colors
    File.open(example_path('lambda-red.ppm')) do |ppm6|
      ppm_reader = PPMReader.new(ppm6, :true_coloring => true)
      assert_equal '5faa2b046cc3e030f86588e472683834',
        Digest::MD5.hexdigest(ppm_reader.to_s)
    end
  end

  def test_to_a
    File.open(example_path('lambda-red.ppm')) do |ppm6|
      ppm_reader = PPMReader.new(ppm6, :gray => false)
      ary = ppm_reader.to_a
      assert_equal 22, ary.size
      assert_equal 44, ary.first.size
      assert_equal [ 255, 255, 255 ], ary.first.last
    end
  end

  private

  def example_path(path = [])
    File.expand_path(File.join(File.dirname(__FILE__), '..', 'examples', *path))
  end
end
