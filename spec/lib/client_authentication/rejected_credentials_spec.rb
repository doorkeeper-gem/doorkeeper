# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ClientAuthentication::RejectedCredentials do
  subject(:credentials) { described_class.new }

  it "is present, so the request is not taken for one without client authentication" do
    expect(credentials).to be_present
    expect(credentials).to be_rejected
  end

  it "names no client and carries no secret" do
    expect(credentials.uid).to be_nil
    expect(credentials.secret).to be_nil
  end
end
