# frozen_string_literal: true

class AddAccessTokenToAccessGrants < ActiveRecord::Migration[6.1]
  def change
    add_reference :oauth_access_grants, :access_token, index: false
  end
end
