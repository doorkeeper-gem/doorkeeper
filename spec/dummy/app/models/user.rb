# frozen_string_literal: true

class ApplicationRecord < ::ActiveRecord::Base
  self.abstract_class = true
end

class User < ApplicationRecord
  def self.authenticate!(name, password)
    User.where(name: name, password: password).first
  end
end
