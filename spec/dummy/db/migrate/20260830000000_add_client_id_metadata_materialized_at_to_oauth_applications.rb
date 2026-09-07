# frozen_string_literal: true

# The attribute use_client_id_metadata_documents reads and writes to tell
# the application rows it materialized from fetched documents apart from
# registered applications (Doorkeeper itself adds no such column; hosts
# enabling the feature do).
class AddClientIdMetadataMaterializedAtToOauthApplications < ActiveRecord::Migration[6.1]
  def change
    add_column :oauth_applications, :client_id_metadata_materialized_at, :datetime
  end
end
