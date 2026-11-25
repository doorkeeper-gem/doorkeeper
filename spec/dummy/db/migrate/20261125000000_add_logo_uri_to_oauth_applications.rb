# frozen_string_literal: true

# The optional logo_uri attribute a client ID metadata document's logo is kept
# in when a host application defines it (Doorkeeper itself adds no such column).
class AddLogoUriToOauthApplications < ActiveRecord::Migration[6.1]
  def change
    add_column :oauth_applications, :logo_uri, :string, limit: 2048
  end
end
