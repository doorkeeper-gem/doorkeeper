require "spec_helper"

describe "Bundler without flag" do
  it "passes --without flag to Bundler on install" do
    build_gems %w(pancake orange_juice waffle coffee sausage soda)

    build_gemfile <<-Gemfile
      source "https://rubygems.org"

      gem "pancake"
      gem "rake", "~> 10.5", :platform => :ruby_18

      group :drinks do
        gem "orange_juice"
      end

      gem "appraisal", :path => #{PROJECT_ROOT.inspect}
    Gemfile

    build_appraisal_file <<-Appraisals
      appraise "breakfast" do
        gem "waffle"

        group :drinks do
          gem "coffee"
        end
      end

      appraise "lunch" do
        gem "sausage"

        group :drinks do
          gem "soda"
        end
      end
    Appraisals

    run "bundle install --local"
    output = run "appraisal install --without drinks"

    expect(output).to include("Bundle complete")
    expect(output).to(
      match(/Gems in the group ['"]?drinks['"]? were not installed/),
    )
    expect(output).not_to include("orange_juice")
    expect(output).not_to include("coffee")
    expect(output).not_to include("soda")

    output = run "appraisal install"

    expect(output).to include("The Gemfile's dependencies are satisfied")
  end
end
