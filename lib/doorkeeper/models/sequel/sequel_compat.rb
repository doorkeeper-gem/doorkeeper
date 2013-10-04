module Doorkeeper
  module Models
    module SequelCompat
      extend ActiveSupport::Concern

      included do
        plugin :timestamps, update_on_create: true
        plugin :association_proxies
      end

      def to_param
        id
      end

      module ClassMethods
        def create!(*args)
          create(*args)
        end

        def find(id)
          if id.kind_of?(Fixnum) || id.kind_of?(String)
            self[id.to_i]
          else
            super
          end
        end
      end
    end
  end
end
