# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Doorkeeper table name computation" do
  context "when pluralize_table_names is disabled" do
    def doorkeeper_model(mixin)
      Class.new(ApplicationRecord) do
        self.pluralize_table_names = false
        include mixin
      end
    end

    it "uses the singular access grant table name" do
      expect(doorkeeper_model(Doorkeeper::Orm::ActiveRecord::Mixins::AccessGrant).table_name)
        .to eq("oauth_access_grant")
    end

    it "uses the singular access token table name" do
      expect(doorkeeper_model(Doorkeeper::Orm::ActiveRecord::Mixins::AccessToken).table_name)
        .to eq("oauth_access_token")
    end

    it "uses the singular application table name" do
      expect(doorkeeper_model(Doorkeeper::Orm::ActiveRecord::Mixins::Application).table_name)
        .to eq("oauth_application")
    end
  end
end
