class EnablePkce < ActiveRecord::Migration
  def change
    add_column :oauth_access_grants, :code_challenge, :string, null: true
    add_column :oauth_access_grants, :transformation_method, :string, null: true
  end
end
