class AddScopesToOauthApplications < ActiveRecord::Migration
  def change
    add_column :oauth_applications, :scopes, :string, null: false, default: ''
  end
end
