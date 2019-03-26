# frozen_string_literal: true

require "spec_helper"

module Doorkeeper::OAuth
  describe PasswordAccessTokenRequest do
    let(:server) do
      double(
        :server,
        default_scopes: Doorkeeper::OAuth::Scopes.new,
        access_token_expires_in: 2.hours,
        refresh_token_enabled?: false,
        custom_access_token_expires_in: lambda { |context|
          context.grant_type == Doorkeeper::OAuth::PASSWORD ? 1234 : nil
        }
      )
    end
    let(:client) { FactoryBot.create(:application) }
    let(:owner)  { double :owner, id: 99 }

    before do
      allow(server).to receive(:option_defined?).with(:custom_access_token_expires_in).and_return(true)
    end

    subject do
      PasswordAccessTokenRequest.new(server, client, owner)
    end

    it "issues a new token for the client" do
      expect do
        subject.authorize
      end.to change { client.reload.access_tokens.count }.by(1)

      expect(client.reload.access_tokens.max_by(&:created_at).expires_in).to eq(1234)
    end

    it "issues a new token without a client" do
      expect do
        subject.client = nil
        subject.authorize
      end.to change { Doorkeeper::AccessToken.count }.by(1)
    end

    it "does not issue a new token with an invalid client" do
      expect do
        subject.client = nil
        subject.parameters = { client_id: "bad_id" }
        subject.authorize
      end.not_to(change { Doorkeeper::AccessToken.count })

      expect(subject.error).to eq(:invalid_client)
    end

    it "requires the owner" do
      subject.resource_owner = nil
      subject.validate
      expect(subject.error).to eq(:invalid_grant)
    end

    it "optionally accepts the client" do
      subject.client = nil
      expect(subject).to be_valid
    end

    it "creates token even when there is already one (default)" do
      FactoryBot.create(:access_token, application_id: client.id, resource_owner_id: owner.id)

      expect do
        subject.authorize
      end.to change { Doorkeeper::AccessToken.count }.by(1)
    end

    it "skips token creation if there is already one reusable" do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)
      FactoryBot.create(:access_token, application_id: client.id, resource_owner_id: owner.id)

      expect do
        subject.authorize
      end.not_to(change { Doorkeeper::AccessToken.count })
    end

    it "creates token when there is already one but non reusable" do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)
      FactoryBot.create(:access_token, application_id: client.id, resource_owner_id: owner.id)
      allow_any_instance_of(Doorkeeper::AccessToken).to receive(:reusable?).and_return(false)

      expect do
        subject.authorize
      end.to change { Doorkeeper::AccessToken.count }.by(1)
    end

    it "calls configured request callback methods" do
      expect(Doorkeeper.configuration.before_successful_strategy_response)
        .to receive(:call).with(subject).once

      expect(Doorkeeper.configuration.after_successful_strategy_response)
        .to receive(:call).with(subject, instance_of(Doorkeeper::OAuth::TokenResponse)).once

      subject.authorize
    end

    describe "with scopes" do
      subject do
        PasswordAccessTokenRequest.new(server, client, owner, scope: "public")
      end

      context "when scopes_by_grant_type is not configured for grant_type" do
        it "returns error when scopes are invalid" do
          allow(server).to receive(:scopes).and_return(Doorkeeper::OAuth::Scopes.from_string("another"))
          subject.validate
          expect(subject.error).to eq(:invalid_scope)
        end

        it "creates the token with scopes if scopes are valid" do
          allow(server).to receive(:scopes).and_return(Doorkeeper::OAuth::Scopes.from_string("public"))
          expect do
            subject.authorize
          end.to change { Doorkeeper::AccessToken.count }.by(1)

          expect(Doorkeeper::AccessToken.last.scopes).to include("public")
        end
      end

      context "when scopes_by_grant_type is configured for grant_type" do
        it "returns error when scopes are valid but not permitted for grant_type" do
          allow(server)
            .to receive(:scopes).and_return(Doorkeeper::OAuth::Scopes.from_string("public"))
          allow(Doorkeeper.configuration)
            .to receive(:scopes_by_grant_type).and_return(password: "another")
          subject.validate
          expect(subject.error).to eq(:invalid_scope)
        end

        it "creates the token with scopes if scopes are valid and permitted for grant_type" do
          allow(server).to receive(:scopes).and_return(Doorkeeper::OAuth::Scopes.from_string("public"))
          allow(Doorkeeper.configuration)
            .to receive(:scopes_by_grant_type).and_return(password: [:public])

          expect do
            subject.authorize
          end.to change { Doorkeeper::AccessToken.count }.by(1)

          expect(Doorkeeper::AccessToken.last.scopes).to include("public")
        end
      end
    end

    describe "with custom expiry" do
      let(:server) do
        double(
          :server,
          default_scopes: Doorkeeper::OAuth::Scopes.new,
          access_token_expires_in: 2.hours,
          refresh_token_enabled?: false,
          custom_access_token_expires_in: lambda { |context|
            if context.scopes.exists?("public")
              222
            elsif context.scopes.exists?("magic")
              Float::INFINITY
            else
              nil
            end
          }
        )
      end

      before do
        allow(server).to receive(:option_defined?).with(:custom_access_token_expires_in).and_return(true)
      end

      it "checks scopes" do
        subject = PasswordAccessTokenRequest.new(server, client, owner, scope: "public")
        allow(server).to receive(:scopes).and_return(Doorkeeper::OAuth::Scopes.from_string("public"))

        expect do
          subject.authorize
        end.to change { Doorkeeper::AccessToken.count }.by(1)

        expect(Doorkeeper::AccessToken.last.expires_in).to eq(222)
      end

      it "falls back to the default otherwise" do
        subject = PasswordAccessTokenRequest.new(server, client, owner, scope: "private")
        allow(server).to receive(:scopes).and_return(Doorkeeper::OAuth::Scopes.from_string("private"))

        expect do
          subject.authorize
        end.to change { Doorkeeper::AccessToken.count }.by(1)

        expect(Doorkeeper::AccessToken.last.expires_in).to eq(2.hours)
      end
    end
  end
end
