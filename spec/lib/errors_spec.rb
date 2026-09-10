# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Errors do
  describe Doorkeeper::Errors::MissingConfigurationBuilderClass do
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

  describe Doorkeeper::Errors::MultipleAccessTokenMethods do
    it "is a Doorkeeper error" do
      expect(described_class.ancestors).to include(Doorkeeper::Errors::DoorkeeperError)
    end

    # RFC 6750 §3.1 lists a request that transmits the token by more than one
    # method among the conditions answered with invalid_request, so that is the
    # error type the exception exposes to Helpers::Controller's
    # get_error_response_from_exception, with the reason that selects the
    # error_description.
    it "reports itself as an invalid_request error" do
      expect(described_class.new.type).to eq(:invalid_request)
    end

    it "names the reason for the error description" do
      expect(described_class.new.reason).to eq(:multiple_access_token_methods)
    end
  end
end
