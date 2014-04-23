class AddAssertionToUsers < ActiveRecord::Migration
  def change
    add_column :users, :assertion, :string
  end
end
