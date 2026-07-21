# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Models::ExpirationTimeSqlMath do
  describe "adapter specific SQL generators" do
    let(:model) { Doorkeeper::AccessToken }

    {
      Doorkeeper::Models::ExpirationTimeSqlMath::SqlLiteExpirationTimeSqlGenerator =>
        "DATETIME(oauth_access_tokens.created_at, '+' || oauth_access_tokens.expires_in || ' SECONDS')",
      Doorkeeper::Models::ExpirationTimeSqlMath::MySqlExpirationTimeSqlGenerator =>
        "DATE_ADD(oauth_access_tokens.created_at, INTERVAL oauth_access_tokens.expires_in SECOND)",
      Doorkeeper::Models::ExpirationTimeSqlMath::PostgresExpirationTimeSqlGenerator =>
        "oauth_access_tokens.created_at + oauth_access_tokens.expires_in * INTERVAL '1 SECOND'",
      Doorkeeper::Models::ExpirationTimeSqlMath::SqlServerExpirationTimeSqlGenerator =>
        "DATEADD(second, oauth_access_tokens.expires_in, oauth_access_tokens.created_at) AT TIME ZONE 'UTC'",
      Doorkeeper::Models::ExpirationTimeSqlMath::OracleExpirationTimeSqlGenerator =>
        "oauth_access_tokens.created_at + INTERVAL to_char(oauth_access_tokens.expires_in) second",
    }.each do |generator_class, expected_sql|
      it "generates the expiration SQL for #{generator_class.name.demodulize}" do
        expect(generator_class.new(model).generate_sql).to eq(expected_sql)
      end
    end

    it "requires subclasses of the base generator to define generate_sql" do
      expect { described_class::ExpirationTimeSqlGenerator.new(model).generate_sql }
        .to raise_error(RuntimeError, /`generate_sql` should be overridden/)
    end
  end

  describe ".expiration_time_sql" do
    context "with a custom SQL expression" do
      let(:model_class) do
        Class.new(Doorkeeper::AccessToken) do
          def self.custom_expiration_time_sql
            "datetime(created_at, '+' || expires_in || ' seconds')"
          end
        end
      end

      it "reports expiration time math as supported regardless of the adapter" do
        allow(model_class).to receive(:adapter_name).and_return("unknown_adapter")

        expect(model_class.supports_expiration_time_math?).to be(true)
      end

      it "prefers the custom SQL over the adapter mapping" do
        expect(model_class.expiration_time_sql)
          .to eq("datetime(created_at, '+' || expires_in || ' seconds')")
      end
    end
  end
end
