require 'spec_helper'

describe 'CLI', 'appraisal update' do
  before do
    build_gem 'dummy2', '1.0.0'

    build_appraisal_file <<-Appraisal
      appraise 'dummy' do
        gem 'dummy', '~> 1.0.0'
        gem 'dummy2', '~> 1.0.0'
      end
    Appraisal

    run 'appraisal install'
    build_gem 'dummy', '1.0.1'
    build_gem 'dummy2', '1.0.1'
  end

  after do
    in_test_directory do
      `gem uninstall dummy -v 1.0.1`
      `gem uninstall dummy2 -a`
    end
  end

  context 'with no arguments' do
    it 'updates all the gems' do
      output = run 'appraisal update'

      expect(output).to include("gemfiles/dummy.gemfile bundle update")
      expect(content_of 'gemfiles/dummy.gemfile.lock').to include 'dummy (1.0.1)'
      expect(content_of 'gemfiles/dummy.gemfile.lock').to include 'dummy2 (1.0.1)'
    end
  end

  context 'with a list of gems' do
    it 'only updates specified gems' do
      run 'appraisal update dummy'

      expect(content_of 'gemfiles/dummy.gemfile.lock').to include 'dummy (1.0.1)'
      expect(content_of 'gemfiles/dummy.gemfile.lock').to include 'dummy2 (1.0.0)'
    end
  end
end
