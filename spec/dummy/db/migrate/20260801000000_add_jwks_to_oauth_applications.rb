# frozen_string_literal: true

# The optional jwks / jwks_uri attributes the private_key_jwt client
# authentication method reads from the application model when a host
# application defines them (Doorkeeper itself adds no such columns).
class AddJwksToOauthApplications < ActiveRecord::Migration[6.1]
  def change
    add_column :oauth_applications, :jwks, :text
    add_column :oauth_applications, :jwks_uri, :string
  end
end
