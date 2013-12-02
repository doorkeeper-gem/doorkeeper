class PluralizeRedirectUriInApplication < ActiveRecord::Migration
  def change
    rename_column :oauth_applications, :redirect_uri, :redirect_uris
    change_column :oauth_applications, :redirect_uris, :text, :null => false, :limit => nil
  end
end