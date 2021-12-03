# frozen_string_literal: true

module Doorkeeper
  module Models
    module ExpirationTimeSqlMath
      extend ::ActiveSupport::Concern

      class ExpirationTimeSqlGenerator
        attr_reader :model

        delegate :table_name, to: :@model

        def initialize(model)
          @model = model
        end

        def generate_sql
          raise "`generate_sql` should be overridden for a #{self.class.name}!"
        end
      end

      class MySqlExpirationTimeSqlGenerator < ExpirationTimeSqlGenerator
        def generate_sql
          Arel.sql("DATE_ADD(#{table_name}.created_at, INTERVAL #{table_name}.expires_in SECOND)")
        end
      end

      class SqlLiteExpirationTimeSqlGenerator < ExpirationTimeSqlGenerator
        def generate_sql
          Arel.sql("DATETIME(#{table_name}.created_at, '+' || #{table_name}.expires_in || ' SECONDS')")
        end
      end

      class SqlServerExpirationTimeSqlGenerator < ExpirationTimeSqlGenerator
        def generate_sql
          Arel.sql("DATEADD(second, #{table_name}.expires_in, #{table_name}.created_at) AT TIME ZONE 'UTC'")
        end
      end

      class OracleExpirationTimeSqlGenerator < ExpirationTimeSqlGenerator
        def generate_sql
          Arel.sql("#{table_name}.created_at + INTERVAL to_char(#{table_name}.expires_in) second")
        end
      end

      class PostgresExpirationTimeSqlGenerator < ExpirationTimeSqlGenerator
        def generate_sql
          Arel.sql("#{table_name}.created_at + #{table_name}.expires_in * INTERVAL '1 SECOND'")
        end
      end

      ADAPTERS_MAPPING = {
        "sqlite" => SqlLiteExpirationTimeSqlGenerator,
        "sqlite3" => SqlLiteExpirationTimeSqlGenerator,
        "postgis" => PostgresExpirationTimeSqlGenerator,
        "postgresql" => PostgresExpirationTimeSqlGenerator,
        "mysql" => MySqlExpirationTimeSqlGenerator,
        "mysql2" => MySqlExpirationTimeSqlGenerator,
        "sqlserver" => SqlServerExpirationTimeSqlGenerator,
        "oracleenhanced" => OracleExpirationTimeSqlGenerator,
      }.freeze

      module ClassMethods
        def supports_expiration_time_math?
          ADAPTERS_MAPPING.key?(adapter_name.downcase) ||
            respond_to?(:custom_expiration_time_sql)
        end

        def expiration_time_sql
          if respond_to?(:custom_expiration_time_sql)
            custom_expiration_time_sql
          else
            expiration_time_sql_expression
          end
        end

        def expiration_time_sql_expression
          ADAPTERS_MAPPING.fetch(adapter_name.downcase).new(self).generate_sql
        end

        def adapter_name
          ActiveRecord::Base.connection.adapter_name
        end
      end
    end
  end
end
