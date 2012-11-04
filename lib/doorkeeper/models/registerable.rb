module Doorkeeper
  module Models
    module Registerable
      extend ActiveSupport::Concern

      included do
        validates :redirect_uri, :redirect_uri => true, :presence => true

        before_create :generate_credentials

        attr_accessible :redirect_uri
      end

      def credentials
        OAuth::Client::Credentials.new uid, secret
      end

      def generate_credentials
        generate_uid
        generate_secret
      end

      def generate_credentials!
        generate_credentials && save(:validate => false)
      end

      def generate_uid
        self.uid = SecureRandom.hex(32)
      end

      def generate_uid!
        generate_uid && save(:validate => false)
      end

      def generate_secret
        self.secret = SecureRandom.hex(32)
      end

      def generate_secret!
        generate_secret && save(:validate => false)
      end

      def reset_credentials
        self.uid = nil
        self.secret = nil
      end

      def reset_credentials!
        reset_credentials
        save :validate => false
      end
    end
  end
end
