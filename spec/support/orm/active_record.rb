# frozen_string_literal: true

# load schema to in memory sqlite
ActiveRecord::Migration.verbose = false
load Rails.root.join("db/schema.rb")

# When an ActiveRecord::TransactionRollbackError — a deadlock, a serialization
# failure — is raised out of a transaction, Rails 7.0 invalidates that
# transaction and then throws the connection away. Reconnecting to
# `database: ":memory:"` opens an empty database, so the schema loaded above is
# gone for every example that follows one raising such an error, even where the
# error was stubbed and the connection never actually unusable. Rails 7.1 rolls
# the transaction back and keeps the connection, so the guard below is only paid
# where it is needed.
if ActiveRecord.version < Gem::Version.new("7.1")
  RSpec.configure do |config|
    # Appended so it runs after the example's own cleanup, and defensive about
    # the constant: an example may have hidden ActiveRecord to exercise a
    # deployment without it.
    config.append_after do
      next unless defined?(::ActiveRecord::Base)
      next if ::ActiveRecord::Base.connection.data_source_exists?("oauth_applications")

      load Rails.root.join("db/schema.rb")
    end
  end
end
