# frozen_string_literal: true

module FixtureHelper
  def json_fixture(path)
    JSON.parse(File.read(File.expand_path("../../fixtures/#{path}", __dir__)))
  end
end

RSpec.configuration.send :include, FixtureHelper
