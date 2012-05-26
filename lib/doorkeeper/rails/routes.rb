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
        mapping = Mapper.new.map(&@options)
        mapper.scope 'oauth', :as => 'oauth' do
          mapper.scope :controller => mapping.controllers[:authorizations] do
            mapper.match 'authorize', :via => :get,    :action => :new, :as => mapping.as[:authorizations]
            mapper.match 'authorize', :via => :post,   :action => :create, :as => mapping.as[:authorizations]
            mapper.match 'authorize', :via => :delete, :action => :destroy, :as => mapping.as[:authorizations]
          end
          mapper.scope :controller => mapping.controllers[:tokens] do
            mapper.match 'token', :via => :post, :action => :create, :as => mapping.as[:tokens]
          end
          mapper.resources :applications, :controller => mapping.controllers[:applications]
          mapper.resources :authorized_applications, :only => [:index, :destroy], :controller => mapping.controllers[:authorized_applications]
        end
      end
    end
  end
end
