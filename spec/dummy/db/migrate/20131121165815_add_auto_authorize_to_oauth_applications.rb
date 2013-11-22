class AddAutoAuthorizeToOauthApplications < ActiveRecord::Migration
  def change
    add_column :oauth_applications, :auto_authorize, :boolean
  end
end
