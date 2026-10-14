# frozen_string_literal: true

class AddClientIdMetadataMaterializedAtToApplications < ActiveRecord::Migration[6.1]
  def change
    add_column :oauth_applications, :client_id_metadata_materialized_at, :datetime
  end
end
