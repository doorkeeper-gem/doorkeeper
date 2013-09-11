module Doorkeeper
  module Models
    module SequelCompat
      extend ActiveSupport::Concern

      included do
        plugin :timestamps, update_on_create: true
        plugin :association_proxies
      end

      module ClassMethods
        def self.create!(*args)
          create(*args)
        end

        def self.find(id)
          if id.respond_to?(:keys)
            super
          else
            self[id]
          end
        end
      end
    end
  end
end
