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

    it "adds OAuth sensitive parameters to filter_parameters" do
      Rails.application.config.filter_parameters.clear

      described_class.configure do
        orm DOORKEEPER_ORM
        resource_owner_authenticator { nil }
      end
      described_class.setup_filter_parameters

      filter_params = Rails.application.config.filter_parameters
      expect(filter_params).to include(
        a_kind_of(Regexp).and(match("client_secret")),
      )
      expect(filter_params).to include(
        a_kind_of(Regexp).and(match("access_token")),
      )
      expect(filter_params).to include(
        a_kind_of(Regexp).and(match("refresh_token")),
      )
      expect(filter_params).to include(
        a_kind_of(Regexp).and(match("authentication_token")),
      )
    end

    it "includes code parameter when authorization_code flow is enabled" do
      Rails.application.config.filter_parameters.clear

      described_class.configure do
        orm DOORKEEPER_ORM
        resource_owner_authenticator { nil }
        grant_flows %w[authorization_code]
      end
      described_class.setup_filter_parameters

      filter_params = Rails.application.config.filter_parameters
      expect(filter_params).to include(
        a_kind_of(Regexp).and(match("code")),
      )
    end

    it "does not include code parameter when authorization_code flow is not enabled" do
      Rails.application.config.filter_parameters.clear

      described_class.configure do
        orm DOORKEEPER_ORM
        resource_owner_authenticator { nil }
        grant_flows %w[client_credentials]
      end
      described_class.setup_filter_parameters

      filter_params = Rails.application.config.filter_parameters
      expect(filter_params.any? { |f| f.is_a?(Regexp) && f.match?("code") }).to be(false)
    end

    it "does not add duplicate filters when called multiple times" do
      Rails.application.config.filter_parameters.clear

      described_class.configure do
        orm DOORKEEPER_ORM
        resource_owner_authenticator { nil }
      end

      2.times { described_class.setup_filter_parameters }

      filters = Rails.application.config.filter_parameters.select do |f|
        f.is_a?(Regexp) && f.match?("access_token")
      end
      expect(filters.size).to eq(1)
    end

    it "does nothing when Doorkeeper is not configured" do
      allow(described_class).to receive(:configured?).and_return(false)

      expect { described_class.setup_filter_parameters }
        .not_to(change { Rails.application.config.filter_parameters })
    end
  end

  describe "#setup" do
    context "with a non-ActiveRecord ORM" do
      after do
        # Restore the real ActiveRecord adapter for the rest of the suite. The
        # orm stub is still active in this hook, so the adapter is restored
        # directly instead of re-running setup.
        described_class.instance_variable_set(:@orm_adapter, Doorkeeper::Orm::ActiveRecord)
      end

      it "runs the deprecated model setup hooks" do
        adapter = double
        stub_const("Doorkeeper::Orm::FakeOrm", adapter)
        allow(described_class.configuration).to receive(:orm).and_return(:fake_orm)

        expect(adapter).to receive(:initialize_models!)
        expect(adapter).to receive(:initialize_application_owner!)

        described_class.setup
      end
    end
  end

  describe "#run_orm_hooks" do
    after do
      described_class.setup
    end

    it "warns when the ORM adapter does not implement run_hooks" do
      legacy_adapter = double(name: "LegacyOrm")
      described_class.instance_variable_set(:@orm_adapter, legacy_adapter)

      expect(Kernel).to receive(:warn).with(/setup logic under `#run_hooks` method/)

      described_class.run_orm_hooks
    end
  end
end
