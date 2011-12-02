require 'doorkeeper/config/scopes'
require 'doorkeeper/config/scope'
require 'doorkeeper/config/scopes_builder'

module Doorkeeper
  def self.configure(&block)
    @config = Config::Builder.new(&block).build
  end

  def self.configuration
    @config
  end

  class Config
    class Builder
      def initialize(&block)
        @config = Config.new
        instance_eval(&block)
      end

      def build
        @config
      end
    end

    module Option

      # Defines configuration option
      #
      # When you call option, it defines two methods. One method will take place
      # in the +Config+ class and the other method will take place in the
      # +Builder+ class.
      #
      # The +name+ parameter will set both builder method and config attribute.
      # If the +:as+ option is defined, the builder method will be the specified
      # option while the config attribute will be the +name+ parameter.
      #
      # ==== Options
      #
      # * [:+as+] Set the builder method that goes inside +configure+ block
      # * [+:default+] The default value in case no option was set
      #
      # ==== Examples
      #
      #    option :name
      #    option :name, :as => :set_name
      #    option :name, :default => "My Name"
      #
      def option(name, options = {})
        attribute = options[:as] || name
        attribute_builder = options[:builder_class]

        Builder.instance_eval do
          define_method name do |*args, &block|
            value = unless attribute_builder
              block ? block : args.first
            else
              attribute_builder.new(&block).build
            end

            @config.instance_variable_set(:"@#{attribute}", value)
          end
        end

        define_method attribute do |*args|
          instance_variable_get(:"@#{attribute}") || options[:default]
        end

        public attribute
      end

      def extended(base)
        base.send(:private, :option)
      end
    end

    extend Option

    option :resource_owner_authenticator, :as      => :authenticate_resource_owner
    option :admin_authenticator,          :as      => :authenticate_admin
    option :access_token_expires_in,      :default => 7200
    option :authorization_scopes,         :as      => :scopes, :builder_class => ScopesBuilder
  end
end
