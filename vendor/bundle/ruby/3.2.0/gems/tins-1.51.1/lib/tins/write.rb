require 'tins/secure_write'

module Tins
  # Tins::Write provides secure write functionality that can be extended onto
  # modules/classes to add a `write` method.
  #
  # When a module is extended with Tins::Write, it will:
  # - Extend the module with SecureWrite methods
  # - Conditionally alias `secure_write` to `write` if no existing `write` method exists
  # - Issue a warning if `write` already exists (when $DEBUG is enabled)
  module Write
    # Called when Tins::Write is extended onto a module.
    # Extends the receiving module with SecureWrite functionality
    # and conditionally aliases secure_write to write.
    #
    # @param modul [Module] The module being extended
    def self.extended(modul)
      modul.extend SecureWrite
      if modul.respond_to?(:write)
        $DEBUG and warn "Skipping inclusion of Tins::Write#write method, "\
          "include Tins::Write::SecureWrite#secure_write instead"
      else
        class << modul; self; end.instance_eval do
          alias_method :write, :secure_write
        end
      end
      super
    end
  end
end
