module Doorkeeper
  class Current < ActiveSupport::CurrentAttributes
    attribute :realm
  end
end
