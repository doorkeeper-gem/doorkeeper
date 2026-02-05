require 'rubygems'
require 'bundler/setup'
require "./spec/support/acceptance_test_helpers"
require "./spec/support/stream_helpers"

PROJECT_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..')).freeze
TMP_GEM_ROOT = File.join(PROJECT_ROOT, "tmp", "gems")
ENV["APPRAISAL_UNDER_TEST"] = "1"

RSpec.configure do |config|
  config.raise_errors_for_deprecations!

  config.define_derived_metadata(:file_path => %r{spec\/acceptance\/}) do |metadata|
    metadata[:type] = :acceptance
  end

  config.include AcceptanceTestHelpers, :type => :acceptance

  config.before :suite do
    FileUtils.rm_rf TMP_GEM_ROOT
  end
end
