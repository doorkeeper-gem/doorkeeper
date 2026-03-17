# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper do
  describe "#authenticate" do
    let(:request) { double }

    it "calls OAuth::Token#authenticate" do
      token_strategies = described_class.config.access_token_methods

      expect(Doorkeeper::OAuth::Token).to receive(:authenticate)
        .with(request, *token_strategies)

      described_class.authenticate(request)
    end

    it "accepts custom token strategies" do
      token_strategies = %i[first_way second_way]

      expect(Doorkeeper::OAuth::Token).to receive(:authenticate)
        .with(request, *token_strategies)

      described_class.authenticate(request, token_strategies)
    end
  end

  describe "#setup_filter_parameters" do
    let(:original_filter_parameters) { Rails.application.config.filter_parameters.dup }

    before { original_filter_parameters }

    after do
      Rails.application.config.filter_parameters.replace(original_filter_parameters)
    end

    it "adds OAuth sensitive parameters to filter_parameters on configure" do
      Rails.application.config.filter_parameters.clear

      described_class.configure do
        orm DOORKEEPER_ORM
        resource_owner_authenticator { nil }
      end

      filter_params = Rails.application.config.filter_parameters
      expect(filter_params).to include(
        a_kind_of(Regexp).and(match("client_secret"))
      )
      expect(filter_params).to include(
        a_kind_of(Regexp).and(match("access_token"))
      )
      expect(filter_params).to include(
        a_kind_of(Regexp).and(match("refresh_token"))
      )
      expect(filter_params).to include(
        a_kind_of(Regexp).and(match("authentication_token"))
      )
    end

    it "includes code parameter when authorization_code flow is enabled" do
      Rails.application.config.filter_parameters.clear

      described_class.configure do
        orm DOORKEEPER_ORM
        resource_owner_authenticator { nil }
        grant_flows %w[authorization_code]
      end

      filter_params = Rails.application.config.filter_parameters
      expect(filter_params).to include(
        a_kind_of(Regexp).and(match("code"))
      )
    end

    it "does not include code parameter when authorization_code flow is not enabled" do
      Rails.application.config.filter_parameters.clear

      described_class.configure do
        orm DOORKEEPER_ORM
        resource_owner_authenticator { nil }
        grant_flows %w[client_credentials]
      end

      filter_params = Rails.application.config.filter_parameters
      expect(filter_params.any? { |f| f.is_a?(Regexp) && f.match?("code") }).to be(false)
    end

    it "does not add duplicate filters when configure is called multiple times" do
      Rails.application.config.filter_parameters.clear

      2.times do
        described_class.configure do
          orm DOORKEEPER_ORM
          resource_owner_authenticator { nil }
        end
      end

      filters = Rails.application.config.filter_parameters.select { |f|
        f.is_a?(Regexp) && f.match?("access_token")
      }
      expect(filters.size).to eq(1)
    end
  end
end
