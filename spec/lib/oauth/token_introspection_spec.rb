# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::TokenIntrospection do
  let(:application) { FactoryBot.create(:application) }
  let(:authorized_token) { FactoryBot.create(:access_token, application: application) }
  let(:introspected_token) { FactoryBot.create(:access_token, application: application) }
  let(:server) { double(credentials: nil, context: double(request: double)) }

  before do
    allow(Doorkeeper).to receive(:authenticate).and_return(authorized_token)
  end

  describe "#error_response" do
    it "is nil when the introspection is authorized" do
      introspection = described_class.new(server, introspected_token)

      expect(introspection.authorized?).to be(true)
      expect(introspection.error_response).to be_nil
    end
  end
end
