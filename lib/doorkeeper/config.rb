module Doorkeeper
  def self.configure(&block)
    @config = Config::Builder.new(&block).build
  end

  def self.configuration
    @config
  end

  class Config
    class Builder
      # Helper class to migrate scopes using authorization_scopes block
      # It will be removed in v0.5.x
      class ScopesMigrator
        attr_accessor :default_scopes, :optional_scopes, :translations

        def initialize
          @default_scopes, @optional_scopes, @translations = [], [], {}
        end

        def scope(scope, options = {})
          if options[:default]
            @optional_scopes << scope
          else
            @default_scopes << scope
          end
          @translations[scope] = options[:description]
        end

        def migrate(&block)
          self.instance_eval(&block)
        end
      end

      def initialize(&block)
        @config = Config.new
        instance_eval(&block)
      end

      def build
        @config
      end

      def enable_application_owner(opts={})
        require File.join(File.dirname(__FILE__), 'models', 'ownership')
        Doorkeeper::Application.send :include, Doorkeeper::Models::Ownership
        confirm_application_owner if opts[:confirmation].present? && opts[:confirmation]
      end

      def confirm_application_owner
        @config.instance_variable_set("@confirm_application_owner", true)
      end

      def default_scopes(*scopes)
        @config.instance_variable_set("@default_scopes", Doorkeeper::OAuth::Scopes.from_array(scopes))
      end

      def optional_scopes(*scopes)
        @config.instance_variable_set("@optional_scopes", Doorkeeper::OAuth::Scopes.from_array(scopes))
      end

      def client_credentials(*methods)
        @config.instance_variable_set("@client_credentials", methods)
      end

      def use_refresh_token
        @config.instance_variable_set("@refresh_token_enabled", true)
      end

      # DEPRECATED: use default/optional scopes
      def authorization_scopes(&block)
        migrator = ScopesMigrator.new
        migrator.migrate(&block)
        self.default_scopes *migrator.default_scopes
        self.optional_scopes *migrator.optional_scopes
        @config.instance_variable_set("@authorization_scopes", migrator)
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
      # If you want to introduce another level of config DSL you can
      # define +builder_class+ parameter.
      # Builder should take a block as the initializer parameter and respond to function +build+
      # that returns the value of the config attribute.
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
      #    option :scopes :builder_class => ScopesBuilder
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
          if instance_variable_defined?(:"@#{attribute}")
            instance_variable_get(:"@#{attribute}")
          else
            options[:default]
          end
        end

        public attribute
      end

      def extended(base)
        base.send(:private, :option)
      end
    end

    extend Option

    option :resource_owner_authenticator, :as => :authenticate_resource_owner
    option :admin_authenticator,          :as => :authenticate_admin
    option :resource_owner_from_credentials
    option :access_token_expires_in,      :default => 7200

    def refresh_token_enabled?
      !!@refresh_token_enabled
    end

    def confirm_application_owner?
      !!@confirm_application_owner
    end

    def default_scopes
      @default_scopes ||= Doorkeeper::OAuth::Scopes.new
    end

    def optional_scopes
      @optional_scopes ||= Doorkeeper::OAuth::Scopes.new
    end

    def scopes
      @scopes ||= default_scopes + optional_scopes
    end

    def client_credentials_methods
      @client_credentials ||= [:from_basic, :from_params]
    end

    # DEPRECATED: use default/optional scopes
    def authorization_scopes
      @authorization_scopes
    end
  end
end
