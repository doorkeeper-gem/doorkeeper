class AddPasswordToUsers < ActiveRecord::Migration
  def change
    add_column :users, :password, :string
    add_column :users, :uid, :string
  end
end
