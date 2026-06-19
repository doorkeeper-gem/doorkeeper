# frozen_string_literal: true

# Helpers for exercising Doorkeeper's Application model under different
# `enable_application_owner` configurations.
#
# As of #1832 (fixes #1831) `Mixins::Application` includes
# `Doorkeeper::Models::Ownership` only when `enable_application_owner?` is set —
# the mixin's `included` block runs once, when the model class is first
# defined. The global `config.before` hook (see spec_helper) resets
# Doorkeeper to its default (owner disabled)
# before every example, and the real `Doorkeeper::Application` singleton is
# autoloaded once with the feature off. So a test that needs the owner
# association present must build a *fresh* model class AFTER enabling the
# feature, rather than reconfiguring the already-loaded class at runtime
# (`run_orm_hooks` is a no-op and cannot retro-fit associations).
module ApplicationModelHelper
  # Builds a brand-new Application model whose mixin `included` block runs
  # under the Doorkeeper configuration currently in effect.
  #
  # Pass +name+ when the test reads validation error messages (e.g.
  # `errors[:owner]`): ActiveModel resolves the model name to build the
  # message, which raises on an anonymous class.
  def build_application_model(name: nil, table_name: "oauth_applications")
    model = Class.new(::ActiveRecord::Base) do
      self.table_name = table_name
      include Doorkeeper::Orm::ActiveRecord::Mixins::Application
    end
    model.define_singleton_method(:name) { name } if name
    model
  end
end

RSpec.configure do |config|
  config.include ApplicationModelHelper
end
