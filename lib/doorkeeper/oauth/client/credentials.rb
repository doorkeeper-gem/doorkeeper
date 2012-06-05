module Doorkeeper
  module OAuth
    class Client
      class Credentials < Struct.new(:uid, :secret)
        extend Methods

        def self.from_request(request, *credentials_methods)
          credentials_methods.inject(nil) do |credentials, method|
            method = self.method(method) if method.is_a?(Symbol)
            credentials = Credentials.new *method.call(request)
            break credentials unless credentials.blank?
          end
        end

        def blank?
          uid.blank? || secret.blank?
        end
      end
    end
  end
end
