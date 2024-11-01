# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::Error do
  subject(:error) { described_class.new(:some_error, :some_state, nil) }

  it { expect(error).to respond_to(:name) }
  it { expect(error).to respond_to(:state) }
  it { expect(error).to respond_to(:translate_options) }

  describe "#description" do
    it "is translated from translation messages" do
      expect(I18n).to receive(:translate).with(
        :some_error,
        scope: %i[doorkeeper errors messages],
        default: :server_error,
      )
      error.description
    end

    context "when there are variables" do
      subject(:error) do
        described_class.new(
          :invalid_code_challenge_method,
          :some_state,
          {
            challenge_methods: "foo, bar",
            count: 2,
          }
        )
      end

      it "is translated from translation messages with variables" do
        expect(error.description).to eq("The code challenge method must be one of foo, bar.")
      end
    end
  end
end
