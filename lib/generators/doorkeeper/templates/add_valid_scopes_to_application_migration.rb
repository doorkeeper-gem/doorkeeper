class AddValidScopesToApplication < ActiveRecord::Migration
  def change
    add_column :oauth_applications, :valid_scopes, :string
    add_column :oauth_applications, :scope_required, :boolean
  end
end
