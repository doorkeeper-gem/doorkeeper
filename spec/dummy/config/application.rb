require File.expand_path('boot', __dir__)

require "rails"

%w[
  action_controller/railtie
  action_view/railtie
  sprockets/railtie
].each do |railtie|
  begin
    require railtie
  rescue LoadError
  end
end

Bundler.require(*Rails.groups)

require 'yaml'

orm = if DOORKEEPER_ORM =~ /mongoid/
        Mongoid.load!(File.join(File.dirname(File.expand_path(__FILE__)), "#{DOORKEEPER_ORM}.yml"))
        :mongoid
      else
        DOORKEEPER_ORM
      end
require "#{orm}/railtie"

module Dummy
  class Application < Rails::Application
    if Rails.gem_version < Gem::Version.new('5.1')
      config.action_controller.per_form_csrf_tokens = true
      config.action_controller.forgery_protection_origin_check = true

      ActiveSupport.to_time_preserves_timezone = true

      config.active_record.belongs_to_required_by_default = true

      config.ssl_options = { hsts: { subdomains: true } }
    else
      config.load_defaults "#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
  end
end
