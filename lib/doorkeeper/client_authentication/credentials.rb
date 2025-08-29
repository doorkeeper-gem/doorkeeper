# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    Credentials = Struct.new(:uid, :secret) do
      # Public clients may have their secret blank, but "credentials" are
      # still present
      delegate :blank?, to: :uid
    end
  end
end
