require 'doorkeeper/rails/routes/mapping'
require 'doorkeeper/rails/routes/mapper'

module Doorkeeper
  module Rails
    class Routes
      module Helper
        def use_doorkeeper(options = {}, &block)
          Doorkeeper::Rails::Routes.new(self, &block).generate_routes!(options)
        end
      end

      def self.install!
        ActionDispatch::Routing::Mapper.send :include, Doorkeeper::Rails::Routes::Helper
      end

      attr_accessor :mapper

      def initialize(mapper, &options)
        @mapper, @options = mapper, options
      end

      def generate_routes!(options)
        mapper.scope 'oauth', :module => :doorkeeper, :as => 'oauth' do
          mapper.get    'authorize', :to => "authorizations#new",     :as => :authorization
          mapper.post   'authorize', :to => "authorizations#create",  :as => :authorization
          mapper.delete 'authorize', :to => "authorizations#destroy", :as => :authorization
          mapper.post   'token',     :to => "tokens#create",          :as => :token
          mapper.resources :applications
          mapper.resources :authorized_applications, :only => [:index, :destroy]
        end
      end
    end
  end
end
