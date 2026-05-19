# frozen_string_literal: true

# load schema to in memory sqlite
ActiveRecord::Migration.verbose = false
load Rails.root.join("db/schema.rb")
