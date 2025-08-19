# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ClientAuthentication::Method do
  subject(:method) { described_class.new(name, client_authentication_method) }
  
  let(:name) { "secret_handshake" }
  let(:client_authentication_method) { double }

  it "reflects the given name" do
    expect(method.name).to eq name
  end

  it "reflects the given method" do
    expect(method.method).to eq client_authentication_method
  end

  it "delegates matches_request? to the method" do
    expect(client_authentication_method).to receive(:matches_request?).with({ example: true })

    method.matches_request?({ example: true })
  end
end
