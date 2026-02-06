require "spec_helper"

describe "Bundle with custom path" do
  let(:gem_name) { 'rack' }
  let(:path) { 'vendor/bundle' }

  shared_examples :gemfile_dependencies_are_satisfied do

    it 'installs gems in the --path directory' do
      build_gemfile <<-Gemfile
        source "https://rubygems.org"

        gem 'appraisal', :path => #{PROJECT_ROOT.inspect}
      Gemfile

      build_appraisal_file <<-Appraisals
        appraise "#{gem_name}" do
          gem '#{gem_name}'
        end
      Appraisals

      run %(bundle install --path="#{path}")
      run 'bundle exec appraisal install'

      installed_gem = Dir.glob("tmp/stage/#{path}/#{Gem.ruby_engine}/*/gems/*").
                      map    { |path| path.split('/').last }.
                      select { |gem| gem.include?(gem_name) }
      expect(installed_gem).not_to be_empty

      bundle_output = run 'bundle check'
      expect(bundle_output).to include("The Gemfile's dependencies are satisfied")

      appraisal_output = run 'bundle exec appraisal install'
      expect(appraisal_output).to include("The Gemfile's dependencies are satisfied")
    end
  end

  include_examples :gemfile_dependencies_are_satisfied

  context 'when already installed in vendor/another' do
    before do
      build_gemfile <<-Gemfile
        source "https://rubygems.org"

        gem '#{gem_name}'
      Gemfile

      run 'bundle install --path vendor/another'
    end

    include_examples :gemfile_dependencies_are_satisfied
  end
end
