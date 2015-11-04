class User < ActiveRecord::Base
  if defined?(ActiveModel::MassAssignmentSecurity) &&
     included_modules.include?(ActiveModel::MassAssignmentSecurity)
    attr_accessible :name, :password
  end

  def self.authenticate!(name, password)
    User.where(name: name, password: password).first
  end
end
