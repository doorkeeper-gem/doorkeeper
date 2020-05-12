# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Request::Strategy do
  subject(:strategy) { described_class.new(server) }

  let(:server) { double }

  describe "#initialize" do
    it "sets the server attribute" do
      expect(strategy.server).to eq server
    end
  end

  describe "#request" do
    it "requires an implementation" do
      expect { strategy.request }.to raise_exception NotImplementedError
    end
  end

  describe "a sample Strategy subclass" do
    subject(:strategy) { strategy_class.new(server) }

    let(:fake_request) { double }

    let(:strategy_class) do
      subclass = Class.new(described_class) do
        class << self
          attr_accessor :fake_request
        end

        def request
          self.class.fake_request
        end
      end

      subclass.fake_request = fake_request
      subclass
    end

    it "provides a request implementation" do
      expect(strategy.request).to eq fake_request
    end

    it "authorizes the request" do
      expect(fake_request).to receive :authorize
      strategy.authorize
    end
  end
end
