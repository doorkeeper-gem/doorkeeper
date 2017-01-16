module Doorkeeper
  module OAuth
    class BaseRequest
      include Validations
      include OAuth::RequestConcern
    end
  end
end
