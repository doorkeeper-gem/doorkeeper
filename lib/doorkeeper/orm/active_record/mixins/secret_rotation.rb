# frozen_string_literal: true

module Doorkeeper::Orm::ActiveRecord::Mixins
  # Client secret rotation: the secret superseded by a rotation is retained
  # in `old_secret` and keeps authenticating the client for a grace period.
  # The comparison side lives in +Doorkeeper::ApplicationMixin+, which every
  # ORM shares; this module holds what is Active Record's own.
  module SecretRotation
    extend ActiveSupport::Concern

    included do
      # A retained secret is a live credential, so both columns read as
      # [FILTERED] from #inspect. Declared on the model rather than added to
      # `config.filter_parameters`, which reaches every log line of the host
      # (see #792); SQL bind logging is filtered through the host's own list.
      self.filter_attributes += %i[old_secret old_secret_created_at]
    end

    # Serializes the application attributes minus the ones a rotation writes
    # (see #withhold_rotation_attributes). Every ActiveModel serialization path
    # (#as_json, #to_json) runs through here. A caller naming +old_secret+ in
    # +methods:+ is still answered, as ActiveModel documents.
    #
    # @param options [Hash, nil] serialization options
    #
    # @return [Hash] entity attributes
    #
    def serializable_hash(options = nil)
      super(withhold_rotation_attributes(options))
    end

    private

    # Expressed against `only` as well as `except` because ActiveModel honours
    # one or the other, never both. `old_secret_created_at` goes with the
    # secret: on its own it reports that a rotation is midway through.
    def withhold_rotation_attributes(options)
      opts = options.try(:dup) || {}
      withheld = %w[old_secret old_secret_created_at]

      if opts[:only]
        opts[:only] = Array(opts[:only]).map(&:to_s) - withheld
      else
        opts[:except] = Array(opts[:except]).map(&:to_s) | withheld
      end

      opts
    end
  end
end
