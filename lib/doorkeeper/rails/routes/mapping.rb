module Doorkeeper
  module Rails
    class Routes
      class Mapping
        attr_accessor :controllers, :as

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
        end

        def [](routes)
          {
            :controllers => @controllers[routes],
            :as => @as[routes]
          }
        end
      end
    end
  end
end
