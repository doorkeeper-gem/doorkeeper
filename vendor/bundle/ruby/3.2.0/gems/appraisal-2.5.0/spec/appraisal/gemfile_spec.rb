require 'spec_helper'
require 'appraisal/gemfile'
require 'active_support/core_ext/string/strip'

describe Appraisal::Gemfile do
  include StreamHelpers

  it "supports gemfiles without sources" do
    gemfile = Appraisal::Gemfile.new
    expect(gemfile.to_s.strip).to eq ''
  end

  it "supports multiple sources" do
    gemfile = Appraisal::Gemfile.new
    gemfile.source "one"
    gemfile.source "two"
    expect(gemfile.to_s.strip).to eq %{source "one"\nsource "two"}
  end

  it "ignores duplicate sources" do
    gemfile = Appraisal::Gemfile.new
    gemfile.source "one"
    gemfile.source "one"
    expect(gemfile.to_s.strip).to eq %{source "one"}
  end

  it "preserves dependency order" do
    gemfile = Appraisal::Gemfile.new
    gemfile.gem "one"
    gemfile.gem "two"
    gemfile.gem "three"
    expect(gemfile.to_s).to match(/one.*two.*three/m)
  end

  it "supports symbol sources" do
    gemfile = Appraisal::Gemfile.new
    gemfile.source :one
    expect(gemfile.to_s.strip).to eq %{source :one}
  end

  it 'supports group syntax' do
    gemfile = Appraisal::Gemfile.new

    gemfile.group :development, :test do
      gem "one"
    end

    expect(gemfile.to_s).to eq <<-GEMFILE.strip_heredoc.strip
      group :development, :test do
        gem "one"
      end
    GEMFILE
  end

  it "supports nested DSL within group syntax" do
    gemfile = Appraisal::Gemfile.new

    gemfile.group :development, :test do
      platforms :jruby do
        gem "one"
      end
      git "git://example.com/repo.git" do
        gem "two"
      end
      path ".." do
        gem "three"
      end
    end

    expect(gemfile.to_s).to eq <<-GEMFILE.strip_heredoc.strip
      group :development, :test do
        git "git://example.com/repo.git" do
          gem "two"
        end

        path "../.." do
          gem "three"
        end

        platforms :jruby do
          gem "one"
        end
      end
    GEMFILE
  end

  it 'supports platform syntax' do
    gemfile = Appraisal::Gemfile.new

    gemfile.platform :jruby do
      gem "one"
    end

    expect(gemfile.to_s).to eq <<-GEMFILE.strip_heredoc.strip
      platforms :jruby do
        gem "one"
      end
    GEMFILE
  end

  it "supports nested DSL within platform syntax" do
    gemfile = Appraisal::Gemfile.new

    gemfile.platform :jruby do
      group :development, :test do
        gem "one"
      end
      git "git://example.com/repo.git" do
        gem "two"
      end
      path ".." do
        gem "three"
      end
    end

    expect(gemfile.to_s).to eq <<-GEMFILE.strip_heredoc.strip
      platforms :jruby do
        git "git://example.com/repo.git" do
          gem "two"
        end

        path "../.." do
          gem "three"
        end

        group :development, :test do
          gem "one"
        end
      end
    GEMFILE
  end

  it "supports git syntax" do
    gemfile = Appraisal::Gemfile.new

    gemfile.git "git://example.com/repo.git" do
      gem "one"
    end

    expect(gemfile.to_s).to eq <<-GEMFILE.strip_heredoc.strip
      git "git://example.com/repo.git" do
        gem "one"
      end
    GEMFILE
  end

  it "supports nested DSL within git syntax" do
    gemfile = Appraisal::Gemfile.new

    gemfile.git "git://example.com/repo.git" do
      group :development, :test do
        gem "one"
      end
      platforms :jruby do
        gem "two"
      end
      path ".." do
        gem "three"
      end
    end

    expect(gemfile.to_s).to eq <<-GEMFILE.strip_heredoc.strip
      git "git://example.com/repo.git" do
        path "../.." do
          gem "three"
        end

        group :development, :test do
          gem "one"
        end

        platforms :jruby do
          gem "two"
        end
      end
    GEMFILE
  end

  it "supports path syntax" do
    gemfile = Appraisal::Gemfile.new

    gemfile.path "../path" do
      gem "one"
    end

    expect(gemfile.to_s).to eq <<-GEMFILE.strip_heredoc.strip
      path "../../path" do
        gem "one"
      end
    GEMFILE
  end

  it "supports nested DSL within path syntax" do
    gemfile = Appraisal::Gemfile.new

    gemfile.path "../path" do
      group :development, :test do
        gem "one"
      end
      platforms :jruby do
        gem "two"
      end
      git "git://example.com/repo.git" do
        gem "three"
      end
    end

    expect(gemfile.to_s).to eq <<-GEMFILE.strip_heredoc.strip
      path "../../path" do
        git "git://example.com/repo.git" do
          gem "three"
        end

        group :development, :test do
          gem "one"
        end

        platforms :jruby do
          gem "two"
        end
      end
    GEMFILE
  end

  context "excess new line" do
    context "no contents" do
      it "shows empty string" do
        gemfile = Appraisal::Gemfile.new
        expect(gemfile.to_s).to eq ''
      end
    end

    context "full contents" do
      it "does not show newline at end" do
        gemfile = Appraisal::Gemfile.new
        gemfile.source "source"
        gemfile.gem "gem"
        gemfile.gemspec
        expect(gemfile.to_s).to match(/[^\n]\z/m)
      end
    end

    context "no gemspec" do
      it "does not show newline at end" do
        gemfile = Appraisal::Gemfile.new
        gemfile.source "source"
        gemfile.gem "gem"
        expect(gemfile.to_s).to match(/[^\n]\z/m)
      end
    end
  end

  context "relative path handling" do
    before { stub_const('RUBY_VERSION', '2.3.0') }

    context "in :path option" do
      it "handles dot path" do
        gemfile = Appraisal::Gemfile.new
        gemfile.gem "bacon", :path => "."

        expect(gemfile.to_s).to eq %(gem "bacon", path: "../")
      end

      it "handles relative path" do
        gemfile = Appraisal::Gemfile.new
        gemfile.gem "bacon", :path => "../bacon"

        expect(gemfile.to_s).to eq %(gem "bacon", path: "../../bacon")
      end

      it "handles absolute path" do
        gemfile = Appraisal::Gemfile.new
        gemfile.gem "bacon", :path => "/tmp"

        expect(gemfile.to_s).to eq %(gem "bacon", path: "/tmp")
      end
    end

    context "in :git option" do
      it "handles dot git path" do
        gemfile = Appraisal::Gemfile.new
        gemfile.gem "bacon", :git => "."

        expect(gemfile.to_s).to eq %(gem "bacon", git: "../")
      end

      it "handles relative git path" do
        gemfile = Appraisal::Gemfile.new
        gemfile.gem "bacon", :git => "../bacon"

        expect(gemfile.to_s).to eq %(gem "bacon", git: "../../bacon")
      end

      it "handles absolute git path" do
        gemfile = Appraisal::Gemfile.new
        gemfile.gem "bacon", :git => "/tmp"

        expect(gemfile.to_s).to eq %(gem "bacon", git: "/tmp")
      end

      it "handles git uri" do
        gemfile = Appraisal::Gemfile.new
        gemfile.gem "bacon", :git => "git@github.com:bacon/bacon.git"

        expect(gemfile.to_s).
          to eq %(gem "bacon", git: "git@github.com:bacon/bacon.git")
      end
    end

    context "in path block" do
      it "handles dot path" do
        gemfile = Appraisal::Gemfile.new

        gemfile.path "." do
          gem "bacon"
        end

        expect(gemfile.to_s).to eq <<-gemfile.strip_heredoc.strip
          path "../" do
            gem "bacon"
          end
        gemfile
      end

      it "handles relative path" do
        gemfile = Appraisal::Gemfile.new

        gemfile.path "../bacon" do
          gem "bacon"
        end

        expect(gemfile.to_s).to eq <<-gemfile.strip_heredoc.strip
          path "../../bacon" do
            gem "bacon"
          end
        gemfile
      end

      it "handles absolute path" do
        gemfile = Appraisal::Gemfile.new

        gemfile.path "/tmp" do
          gem "bacon"
        end

        expect(gemfile.to_s).to eq <<-gemfile.strip_heredoc.strip
          path "/tmp" do
            gem "bacon"
          end
        gemfile
      end
    end

    context "in git block" do
      it "handles dot git path" do
        gemfile = Appraisal::Gemfile.new

        gemfile.git "." do
          gem "bacon"
        end

        expect(gemfile.to_s).to eq <<-gemfile.strip_heredoc.strip
          git "../" do
            gem "bacon"
          end
        gemfile
      end

      it "handles relative git path" do
        gemfile = Appraisal::Gemfile.new

        gemfile.git "../bacon" do
          gem "bacon"
        end

        expect(gemfile.to_s).to eq <<-gemfile.strip_heredoc.strip
          git "../../bacon" do
            gem "bacon"
          end
        gemfile
      end

      it "handles absolute git path" do
        gemfile = Appraisal::Gemfile.new

        gemfile.git "/tmp" do
          gem "bacon"
        end

        expect(gemfile.to_s).to eq <<-gemfile.strip_heredoc.strip
          git "/tmp" do
            gem "bacon"
          end
        gemfile
      end

      it "handles git uri" do
        gemfile = Appraisal::Gemfile.new

        gemfile.git "git@github.com:bacon/bacon.git" do
          gem "bacon"
        end

        expect(gemfile.to_s).to eq <<-gemfile.strip_heredoc.strip
          git "git@github.com:bacon/bacon.git" do
            gem "bacon"
          end
        gemfile
      end
    end

    context "in gemspec directive" do
      it "handles gemspec path" do
        gemfile = Appraisal::Gemfile.new
        gemfile.gemspec :path => "."

        expect(gemfile.to_s).to eq %(gemspec path: "../")
      end
    end
  end

  context "git_source support" do
    before { stub_const('RUBY_VERSION', '2.3.0') }

    it "stores git_source declaration and apply it as git option" do
      gemfile = Appraisal::Gemfile.new
      gemfile.git_source(:custom_source) { |repo| "path/#{repo}" }
      gemfile.gem "bacon", :custom_source => "bacon_pancake"

      expect(gemfile.to_s).to eq %(gem "bacon", git: "../path/bacon_pancake")
    end
  end

  it "preserves the Gemfile's __FILE__" do
    gemfile = Appraisal::Gemfile.new
    Tempfile.open do |tmpfile|
      tmpfile.write "__FILE__"
      tmpfile.rewind
      expect(gemfile.load(tmpfile.path)).to include(File.dirname(tmpfile.path))
    end
  end
end
