require 'test_helper'
require 'fileutils'
require 'tempfile'

module Tins
  class FindTest < Test::Unit::TestCase
    include Tins::Find
    include FileUtils

    def setup
      mkdir_p @work_dir = File.join(Dir.tmpdir, "test.#$$")
    end

    def teardown
      rm_rf @work_dir
    end

    def test_raising_errors
      assert_equal [], find(File.join(@work_dir, 'nix'), raise_errors: false).to_a
      assert_equal [], find(File.join(@work_dir, 'nix')).to_a
      assert_raise(Errno::ENOENT) do
        find(File.join(@work_dir, 'nix'), raise_errors: true).to_a
      end
    end

    def test_showing_hidden
      touch file = File.join(@work_dir, '.foo')
      assert_equal [ @work_dir ], find(@work_dir, show_hidden: false).to_a
      assert_equal [ @work_dir, file ], find(@work_dir).to_a
      assert_equal [ @work_dir, file ], find(@work_dir, show_hidden: true).to_a
    end

    def test_check_directory_without_access
      # do not run this test on JRuby
      omit_if(RUBY_PLATFORM =~ /java/, "Can't run the test on JRuby")
      # do not run this test if we're root, as it will fail.
      omit_if(Process::UID.eid == 0, "Can't run the test as root")

      begin
        mkdir_p directory1 = File.join(@work_dir, 'foo')
        mkdir_p directory2 = File.join(directory1, 'bar')
        touch File.join(directory2, 'file')
        chmod 0, directory2
        assert_equal [ @work_dir, directory1, directory2 ], find(@work_dir, raise_errors: false).to_a
        assert_equal [ @work_dir, directory1, directory2 ], find(@work_dir).to_a
        assert_raise(Errno::EACCES) do
          find(@work_dir, raise_errors: true).to_a
        end
      ensure
        File.exist?(directory2) and chmod 0777, directory2
      end
    end

    def test_follow_symlinks
      mkdir_p directory1 = File.join(@work_dir, 'foo1')
      mkdir_p directory2 = File.join(@work_dir, 'foo2')
      mkdir_p directory3 = File.join(directory1, 'bar')
      touch File.join(directory3, 'foo')
      ln_s directory3, link = File.join(directory2, 'baz')
      assert_equal [ directory2, link ], find(directory2, follow_symlinks: false).to_a
      assert_equal [ directory2, link, linked = File.join(link, 'foo') ], find(directory2).to_a
      assert_equal [ directory2, link, linked ], find(directory2, follow_symlinks: true).to_a
    end

    def test_path_file
      File.open(File.join(@work_dir, 'foo'), 'w') do |f|
        f.print "hello"
        f.fsync
        assert_equal "hello", find(@work_dir).
          select { |fs| fs.stat.file? }.first.file.read
      end
    end

    def test_path_extension
      finder = Tins::Find::Finder.new
      f = File.open(path = File.join(@work_dir, 'foo.bar'), 'w')
      ln_s path, path2 = File.join(@work_dir, 'foo2.bar')
      path2 = finder.prepare_path path2
      path = finder.prepare_path path
      assert_true path.exist?
      assert_true path.file?
      assert_false path.directory?
      assert_true finder.prepare_path(Dir.pwd).directory?
      assert_equal Pathname.new(path), path.pathname
      assert_equal 'bar', path.suffix
      assert_true path2.lstat.symlink?
    ensure
      f and rm_f f.path
    end

    def test_suffix
      finder = Tins::Find::Finder.new(suffix: 'bar')
      f = File.open(fpath = File.join(@work_dir, 'foo.bar'), 'w')
      g = File.open(gpath = File.join(@work_dir, 'foo.baz'), 'w')
      fpath = finder.prepare_path fpath
      gpath = finder.prepare_path gpath
      assert_true finder.visit_path?(fpath)
      assert_false finder.visit_path?(gpath)
      finder.suffix = nil
      assert_true finder.visit_path?(fpath)
      assert_true finder.visit_path?(gpath)
    ensure
      f and rm_f f.path
      g and rm_f g.path
    end

    def test_visit
      assert_raise(ArgumentError) do
        Tins::Find::Finder.new(visit: :foo, suffix: 'bla')
      end
      finder = Tins::Find::Finder.new(visit: -> path { path.stat.file? })
      File.new(fpath = File.join(@work_dir, 'foo.bar'), 'w').close
      mkdir_p(gpath = File.join(@work_dir, 'dir'))
      fpath = finder.prepare_path fpath
      gpath = finder.prepare_path gpath
      assert_true finder.visit_path?(fpath)
      assert_false finder.visit_path?(gpath)
      found = []
      Tins::Find.find(
        @work_dir,
        visit: -> path { path.stat.directory? or prune }
      ) { |f| found << f }
      assert_equal [ @work_dir, gpath ], found
    end

    def test_prune
      mkdir_p directory1 = File.join(@work_dir, 'foo1')
      mkdir_p File.join(@work_dir, 'foo2')
      result = []
      find(@work_dir) { |f| f =~ /foo2\z/ and prune; result << f }
      assert_equal [ @work_dir, directory1 ], result
    end
  end
end
