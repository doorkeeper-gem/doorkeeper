# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Errors::MissingConfigurationBuilderClass do
  it "is a Doorkeeper error" do
    expect(described_class.ancestors).to include(Doorkeeper::Errors::DoorkeeperError)
  end

  # Regression test: `Doorkeeper::Config::Option#extended` referenced an error
  # class that was never defined, so extending a class without a `builder_class`
  # raised a NameError ("uninitialized constant") instead of this descriptive
  # error.
  it "is raised when the option DSL is extended without a builder_class" do
    expect do
      Class.new.extend(Doorkeeper::Config::Option)
    end.to raise_error(described_class, /Define `self.builder_class` method/)
  end
end
