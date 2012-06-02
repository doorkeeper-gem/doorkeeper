module Doorkeeper
  module Rails
    class Routes
      class Mapping
        attr_accessor :controllers, :as, :skips

        def initialize
          @controllers = {
            :authorizations => 'doorkeeper/authorizations',
            :applications => 'doorkeeper/applications',
            :authorized_applications => 'doorkeeper/authorized_applications',
            :tokens => 'doorkeeper/tokens',
          }

          @as = {
            :authorizations => :authorization,
            :tokens => :token,
          }

          @skips = []

        end

        def [](routes)
          {
            :controllers => @controllers[routes],
            :as => @as[routes]
          }
        end

        def skipped?(controller)
          return @skips.include?(controller)
        end
      end
    end
  end
end
