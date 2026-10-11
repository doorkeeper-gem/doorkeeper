# frozen_string_literal: true

# The columns backing the `enable_secret_rotation` option: the secret
# superseded by the last `#rotate_secret!`, and when it was retained.
class EnableSecretRotation < ActiveRecord::Migration[6.1]
  def change
    add_column :oauth_applications, :old_secret, :string, null: true
    add_column :oauth_applications, :old_secret_created_at, :datetime, null: true
    add_index :oauth_applications, :old_secret_created_at
  end
end
