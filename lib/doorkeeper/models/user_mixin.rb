module Doorkeeper
  class UserMixin
    extend ActiveSupport::Concern

    include Models::Info
    include Models::DatabaseAuthenticatable
    include Models::Confirmable
    include Models::Lockable
    include Models::Recoverable
    include Models::Omniauthable
    include Models::Avatarable
  end
end
