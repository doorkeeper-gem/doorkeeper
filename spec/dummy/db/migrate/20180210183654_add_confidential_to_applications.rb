# frozen_string_literal: true

class AddConfidentialToApplications < ActiveRecord::Migration[5.1]
  def change
    add_column(
      :oauth_applications,
      :confidential,
      :boolean,
      null: false,
      default: true # maintaining backwards compatibility: require secrets
    )
  end
end
