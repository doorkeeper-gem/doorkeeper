# frozen_string_literal: true

require "spec_helper"

if DOORKEEPER_ORM == :active_record
  RSpec.describe Doorkeeper::Orm::ActiveRecord do
    describe ".initialize_configured_associations" do
      it "uses ActiveSupport.on_load(:active_record) to defer model loading" do
        expect(ActiveSupport).to receive(:on_load).with(:active_record)
        described_class.initialize_configured_associations
      end
    end

    describe "STI (Single Table Inheritance) support" do
      # Ensure STI subclasses work correctly with the ActiveSupport.on_load hook.
      # See: https://github.com/doorkeeper-gem/doorkeeper/issues/1703
      #      https://github.com/doorkeeper-gem/doorkeeper/issues/1513

      context "when application_class is a STI subclass of Doorkeeper::Application" do
        let!(:custom_application_class) do
          Class.new(Doorkeeper::Application) do
            def self.name
              "CustomStiApplication"
            end
          end
        end

        before do
          stub_const("CustomStiApplication", custom_application_class)

          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            enable_application_owner
            application_class "CustomStiApplication"
          end

          Doorkeeper.run_orm_hooks
        end

        it "includes Ownership module in the STI subclass" do
          expect(CustomStiApplication.ancestors).to include(Doorkeeper::Models::Ownership)
        end

        it "STI subclass responds to owner association" do
          instance = CustomStiApplication.new
          expect(instance).to respond_to(:owner)
        end
      end

      context "when access_token_class is a STI subclass of Doorkeeper::AccessToken" do
        let!(:custom_token_class) do
          Class.new(Doorkeeper::AccessToken) do
            def self.name
              "CustomStiAccessToken"
            end
          end
        end

        before do
          stub_const("CustomStiAccessToken", custom_token_class)

          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            access_token_class "CustomStiAccessToken"
          end

          Doorkeeper.run_orm_hooks
        end

        it "includes PolymorphicResourceOwner::ForAccessToken in the STI subclass" do
          expect(CustomStiAccessToken.ancestors).to include(
            Doorkeeper::Models::PolymorphicResourceOwner::ForAccessToken,
          )
        end
      end

      context "when access_grant_class is a STI subclass of Doorkeeper::AccessGrant" do
        let!(:custom_grant_class) do
          Class.new(Doorkeeper::AccessGrant) do
            def self.name
              "CustomStiAccessGrant"
            end
          end
        end

        before do
          stub_const("CustomStiAccessGrant", custom_grant_class)

          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            access_grant_class "CustomStiAccessGrant"
          end

          Doorkeeper.run_orm_hooks
        end

        it "includes PolymorphicResourceOwner::ForAccessGrant in the STI subclass" do
          expect(CustomStiAccessGrant.ancestors).to include(
            Doorkeeper::Models::PolymorphicResourceOwner::ForAccessGrant,
          )
        end
      end
    end
  end
end
