require 'active_record'
require 'database_cleaner/core'

ActiveSupport.on_load(:active_record) do
  require 'database_cleaner/active_record/base'
  require 'database_cleaner/active_record/transaction'
  require 'database_cleaner/active_record/truncation'
  require 'database_cleaner/active_record/deletion'

  DatabaseCleaner[:active_record].strategy = :transaction
end
