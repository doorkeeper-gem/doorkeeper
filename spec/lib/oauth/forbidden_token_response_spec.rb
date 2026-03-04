# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ForbiddenTokenResponse do
  subject(:response) { described_class.new }

  describe "#name" do
    it { expect(response.name).to eq(:insufficient_scope) }
  end

  describe "#status" do
    it { expect(response.status).to eq(:forbidden) }
  end

  describe "#headers" do
    subject(:response) { described_class.from_scopes(["public"]) }

    it "includes a WWW-Authenticate header per RFC 6750 Section 3.1" do
      www_authenticate = response.headers["WWW-Authenticate"]
      expect(www_authenticate).to include('error="insufficient_scope"')
      expect(www_authenticate).to include('Access to this resource requires scope "public".')
    end
  end

  describe ".from_scopes" do
    subject(:response) { described_class.from_scopes(["public"]) }

    it "includes a list of acceptable scopes" do
      expect(response.description).to include("public")
    end

    it "explains that the problem is due to a missing scope" do
      expect(response.description).to match(/requires scope/i)
    end

    it "does not use the scope description from authorize page" do
      expect(response.description).not_to eql("Access your public data")
    end
  end
end
