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
          mapper.scope :controller => mapping.controllers[:authorization] do
            mapper.match 'authorize', :via => :get,    :action => :new,     :as => :authorization
            mapper.match 'authorize', :via => :post,   :action => :create,  :as => :authorization
            mapper.match 'authorize', :via => :delete, :action => :destroy, :as => :authorization
          end
          mapper.post 'token', :to => "doorkeeper/tokens#create", :as => :token
          mapper.resources :applications, :module => :doorkeeper
          mapper.resources :authorized_applications, :only => [:index, :destroy], :module => :doorkeeper
        end
      end
    end
  end
end
