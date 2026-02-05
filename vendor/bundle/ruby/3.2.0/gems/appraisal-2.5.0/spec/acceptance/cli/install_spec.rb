require 'spec_helper'

describe 'CLI', 'appraisal install' do
  it 'raises error when there is no Appraisals file' do
    output = run 'appraisal install 2>&1', false

    expect(output).to include "Unable to locate 'Appraisals' file"
  end

  it 'installs the dependencies' do
    build_appraisal_file <<-Appraisal
      appraise '1.0.0' do
        gem 'dummy', '1.0.0'
      end

      appraise '1.1.0' do
        gem 'dummy', '1.1.0'
      end
    Appraisal

    run 'appraisal install'

    expect(file 'gemfiles/1.0.0.gemfile.lock').to be_exists
    expect(file 'gemfiles/1.1.0.gemfile.lock').to be_exists
  end

  it 'relativize directory in gemfile.lock' do
    build_gemspec
    add_gemspec_to_gemfile

    build_appraisal_file <<-Appraisal
      appraise '1.0.0' do
        gem 'dummy', '1.0.0'
      end
    Appraisal

    run 'appraisal install'

    expect(content_of("gemfiles/1.0.0.gemfile.lock")).
      not_to include(current_directory)
  end

  it "does not relativize directory of uris in gemfile.lock" do
    build_gemspec
    add_gemspec_to_gemfile

    build_git_gem("uri_dummy")
    uri_dummy_path = "#{current_directory}/uri_dummy"
    FileUtils.symlink(File.absolute_path("tmp/gems/uri_dummy"), uri_dummy_path)

    build_appraisal_file <<-APPRAISAL
      appraise '1.0.0' do
        gem 'uri_dummy', git: 'file://#{uri_dummy_path}'
      end
    APPRAISAL

    run "appraisal install"

    expect(content_of("gemfiles/1.0.0.gemfile.lock")).
      to include("file://#{uri_dummy_path}")
  end

  context 'with job size', :parallel => true do
    before do
      build_appraisal_file <<-Appraisal
        appraise '1.0.0' do
          gem 'dummy', '1.0.0'
        end
      Appraisal
    end

    it 'accepts --jobs option to set job size' do
      output = run 'appraisal install --jobs=2'

      expect(output).to include(
        "bundle install --gemfile='#{file('gemfiles/1.0.0.gemfile')}' --jobs=2"
      )
    end

    it 'ignores --jobs option if the job size is less than or equal to 1' do
      output = run 'appraisal install --jobs=0'

      expect(output).to include(
        "bundle install --gemfile='#{file('gemfiles/1.0.0.gemfile')}'"
      )
      expect(output).not_to include(
        "bundle install --gemfile='#{file('gemfiles/1.0.0.gemfile')}' --jobs=0"
      )
      expect(output).not_to include(
        "bundle install --gemfile='#{file('gemfiles/1.0.0.gemfile')}' --jobs=1"
      )
    end
  end

  context "with full-index", :parallel do
    before do
      build_appraisal_file <<-APPRAISAL
        appraise '1.0.0' do
          gem 'dummy', '1.0.0'
        end
      APPRAISAL
    end

    it "accepts --full-index option to pull the full RubyGems index" do
      output = run("appraisal install --full-index")

      expect(output).to include(
        "bundle install --gemfile='#{file('gemfiles/1.0.0.gemfile')}' " \
        "--retry 1 --full-index true"
      )
    end
  end

  context "with path", :parallel do
    before do
      build_appraisal_file <<-APPRAISAL
        appraise '1.0.0' do
          gem 'dummy', '1.0.0'
        end
      APPRAISAL
    end

    it "accepts --path option to specify the location to install gems into" do
      output = run("appraisal install --path vendor/appraisal")

      expect(output).to include(
        "bundle install --gemfile='#{file('gemfiles/1.0.0.gemfile')}' " \
        "--path #{file('vendor/appraisal')} --retry 1",
      )
    end
  end
end
