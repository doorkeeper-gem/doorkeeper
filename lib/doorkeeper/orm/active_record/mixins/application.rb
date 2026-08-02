# frozen_string_literal: true

module Doorkeeper::Orm::ActiveRecord::Mixins
  module Application
    extend ActiveSupport::Concern

    included do
      self.table_name = compute_doorkeeper_table_name
      self.strict_loading_by_default = false if respond_to?(:strict_loading_by_default)

      include ::Doorkeeper::ApplicationMixin
      # `enable_application_owner?` is read once, at parent-class autoload
      # time (#1831): with the feature off the model exposes no `:owner`
      # association — avoiding a misleading reflection on schemas that lack
      # the owner columns. The flag is therefore a load-time switch; turning
      # it on later requires defining a fresh model class.
      include ::Doorkeeper::Models::Ownership if Doorkeeper.config.enable_application_owner?

      has_many :access_grants,
               foreign_key: :application_id,
               dependent: :delete_all,
               class_name: Doorkeeper.config.access_grant_class.to_s

      has_many :access_tokens,
               foreign_key: :application_id,
               dependent: :delete_all,
               class_name: Doorkeeper.config.access_token_class.to_s

      validates :name, :uid, presence: true
      validates :secret, presence: true, if: -> { secret_required? }
      validates :uid, uniqueness: { case_sensitive: true }
      validates :confidential, inclusion: { in: [true, false] }

      validates_with Doorkeeper::RedirectUriValidator, attributes: [:redirect_uri]

      validate :scopes_match_configured, if: :enforce_scopes?

      before_validation :generate_uid, :generate_secret, on: :create

      has_many :authorized_tokens,
               -> { where(revoked_at: nil) },
               foreign_key: :application_id,
               class_name: Doorkeeper.config.access_token_class.to_s

      has_many :authorized_applications,
               through: :authorized_tokens,
               source: :application

      # Generates a new secret for this application, intended to be used
      # for rotating the secret or in case of compromise.
      #
      # @return [String] new transformed secret value
      #
      def renew_secret
        @raw_secret = secret_generator.generate
        secret_strategy.store_secret(self, :secret, @raw_secret)
      end

      # Replaces this application's secret, retaining the superseded one so
      # that clients still presenting it keep authenticating until the
      # application ends the grace period with +#clear_old_secret!+. Requires
      # the `enable_secret_rotation` option and the columns it needs; use
      # +#renew_secret+ for a replacement with no grace period.
      #
      # The superseded secret is carried over as *stored*, not re-derived:
      # hashing strategies draw a fresh salt on every write, so the plaintext
      # is not available to store again — and does not need to be, since both
      # columns are written and read back through the same strategy.
      #
      # Only one generation is retained, mirroring how `previous_refresh_token`
      # keeps a single generation of refresh tokens. Rotating twice in a row
      # therefore ends the first rotation's grace period early: the secret it
      # retained is replaced by the one the second rotation supersedes, and
      # clients that had not yet moved off it stop authenticating. A rotation
      # is meant to be followed by `#clear_old_secret!`, not by another
      # rotation.
      #
      # @param revoke_old [Boolean]
      #   drop the current secret instead of retaining it. For a secret
      #   believed to be compromised, which has to stop working now rather
      #   than at the end of a grace period.
      # @param revoke_tokens [Boolean]
      #   additionally revoke everything the current secret could still be
      #   exchanged for — the access tokens already issued to this
      #   application, and its unredeemed authorization codes, which that
      #   secret is enough to redeem.
      #
      # @return [String] new plain text secret value
      #
      def rotate_secret!(revoke_old: false, revoke_tokens: false)
        # Captured before the guard so that the rescue below restores it even
        # when nothing was attempted: a bare `raise` from the guard must not
        # cost an application the plaintext of the secret it already has.
        previous_raw_secret = @raw_secret
        ensure_secret_rotation_enabled!

        self.class.with_primary_role do
          # Read-modify-write on the row: the secret being retained is the one
          # currently stored, so two rotations racing without a lock would let
          # the later one overwrite a secret the earlier one had already handed
          # to a client — which would then never authenticate. `with_lock`
          # reloads under the lock, so the retained value is the committed one
          # even if this instance was loaded before the other rotation.
          with_lock do
            if revoke_old
              self.old_secret = nil
              self.old_secret_created_at = nil
            else
              self.old_secret = secret
              self.old_secret_created_at = Time.now.utc
            end

            renew_secret
            save!

            revoke_issued_credentials! if revoke_tokens
          end
        end

        plaintext_secret
      rescue StandardError
        # The row is rolled back, but Active Record leaves the in-memory
        # attributes as the failed write left them — an instance still holding
        # a secret that was never stored is a trap for any caller that rescues
        # and carries on. The volatile plaintext is put back with them, so
        # `#plaintext_secret` keeps describing the secret that is actually
        # stored rather than the one the failed rotation would have written.
        #
        # Only the columns this method writes are restored: anything else the
        # caller had changed on the instance is theirs, and a failed rotation
        # is no reason to discard it.
        restore_attributes(%w[secret old_secret old_secret_created_at])
        @raw_secret = previous_raw_secret
        raise
      end

      # Ends the grace period opened by the last rotation, dropping the
      # superseded secret. When that happens is left to the application — a
      # console, an admin action, a rake task, or a job driven by
      # +old_secret_created_at+: Doorkeeper expires nothing on its own, so an
      # old secret that is never cleared stays valid indefinitely.
      #
      # Takes the row lock for the same reason +#rotate_secret!+ does, and
      # decides whether there is anything to clear under it: read outside the
      # lock, the answer describes whatever this instance was loaded with,
      # which a rotation committed since then has already made wrong in both
      # directions. As with a rotation, taking the lock requires a record free
      # of unsaved changes.
      #
      # @return [Boolean] whether an old secret was there to clear
      #
      def clear_old_secret!
        ensure_secret_rotation_enabled!

        cleared = false

        self.class.with_primary_role do
          with_lock do
            next if old_secret.blank?

            update!(old_secret: nil, old_secret_created_at: nil)
            cleared = true
          end
        end

        cleared
      rescue StandardError
        # Symmetric with #rotate_secret!: the row is rolled back, so the
        # instance must not be left claiming a grace period it still has.
        # Only the columns this method writes are restored.
        restore_attributes(%w[old_secret old_secret_created_at])
        raise
      end

      # We keep a volatile copy of the raw secret for initial communication
      # The stored refresh_token may be mapped and not available in cleartext.
      #
      # Some strategies allow restoring stored secrets (e.g. symmetric encryption)
      # while hashing strategies do not, so you cannot rely on this value
      # returning a present value for persisted tokens.
      def plaintext_secret
        if secret_strategy.allows_restoring_secrets?
          secret_strategy.restore_secret(self, :secret)
        else
          @raw_secret
        end
      end

      # Represents client as set of it's attributes in JSON format.
      # This is the right way how we want to override ActiveRecord #to_json.
      #
      # Respects privacy settings and serializes minimum set of attributes
      # for public/private clients and full set for authorized owners.
      #
      # @return [Hash] entity attributes for JSON
      #
      def as_json(options = {})
        # if application belongs to some owner we need to check if it's the same as
        # the one passed in the options or check if we render the client as an owner
        if (respond_to?(:owner) && owner && owner == options[:current_resource_owner]) ||
           options[:as_owner]
          # Owners can see all the client attributes, fallback to ActiveModel
          # serialization — minus the ones a rotation writes, which are never
          # serialized for anyone.
          super(withhold_rotation_attributes(options))
        else
          # if application has no owner or it's owner doesn't match one from the options
          # we render only minimum set of attributes that could be exposed to a public
          only = extract_serializable_attributes(options)
          super(options.merge(only: only))
        end
      end

      def authorized_for_resource_owner?(resource_owner)
        Doorkeeper.configuration.authorize_resource_owner_for_client.call(self, resource_owner)
      end

      # We need to hook into this method to allow serializing plan-text secrets
      # when secrets hashing enabled.
      #
      # @param key [String] attribute name
      #
      def read_attribute_for_serialization(key)
        return super unless key.to_s == "secret"

        plaintext_secret || secret
      end

      private

      def ensure_secret_rotation_enabled!
        return if self.class.secret_rotation_enabled?

        raise Doorkeeper::Errors::SecretRotationNotEnabled, self.class.table_name
      end

      # Revokes what the superseded secret could still be exchanged for.
      # Access grants are included because an unredeemed authorization code is
      # exchanged with the client secret (RFC 6749 §4.1.3): leaving the codes
      # alive would hand back an access token minted after the revocation.
      #
      # Already-revoked records are left untouched so their original
      # `revoked_at` survives.
      #
      def revoke_issued_credentials!
        now = Time.now.utc

        access_tokens.where(revoked_at: nil).update_all(revoked_at: now)
        access_grants.where(revoked_at: nil).update_all(revoked_at: now)
      end

      def secret_generator
        generator_name = Doorkeeper.config.application_secret_generator
        generator = generator_name.constantize

        return generator if generator.respond_to?(:generate)

        raise Doorkeeper::Errors::UnableToGenerateToken, "#{generator} does not respond to `.generate`."
      rescue NameError
        raise Doorkeeper::Errors::TokenGeneratorNotFound, "#{generator_name} not found"
      end

      def generate_uid
        self.uid = Doorkeeper::OAuth::Helpers::UniqueToken.generate if uid.blank?
      end

      def generate_secret
        return if secret.present? || !secret_required?

        renew_secret
      end

      def scopes_match_configured
        if scopes.present? && !Doorkeeper::OAuth::Helpers::ScopeChecker.valid?(
          scope_str: scopes.to_s,
          server_scopes: Doorkeeper.config.scopes,
        )
          errors.add(:scopes, :not_match_configured)
        end
      end

      def enforce_scopes?
        Doorkeeper.config.enforce_configured_scopes?
      end

      def secret_required?
        confidential? ||
          !self.class.columns.detect { |column| column.name == "secret" }&.null
      end

      # Removes the columns a rotation writes from serialization options.
      #
      # The retained secret is a live credential — it authenticates the client
      # exactly as `secret` does — so it must not be handed out anywhere, and
      # the owner view is the one path that would otherwise serialize every
      # attribute. `secret` is surfaced there deliberately, through
      # #read_attribute_for_serialization; nothing surfaces this one.
      # `old_secret_created_at` goes with it: on its own it still reports that
      # a client is midway through a rotation.
      #
      # Expressed against `only` as well as `except` because ActiveModel
      # honours one or the other and never both — an explicit
      # `only: [:old_secret]` would walk straight past an exclusion written
      # only as `except`. The `only` branch mirrors ActiveModel's own test
      # (any non-nil value selects that path, including an empty array).
      #
      # @param options [Hash] serialization options
      #
      # @return [Hash] the options with the rotation columns removed
      #
      def withhold_rotation_attributes(options)
        opts = options.try(:dup) || {}
        withheld = %w[old_secret old_secret_created_at]

        if opts[:only]
          opts[:only] = Array.wrap(opts[:only]).map(&:to_s) - withheld
        else
          opts[:except] = Array.wrap(opts[:except]).map(&:to_s) | withheld
        end

        opts
      end

      # Helper method to extract collection of serializable attribute names
      # considering serialization options (like `only`, `except` and so on).
      #
      # @param options [Hash] serialization options
      #
      # @return [Array<String>]
      #   collection of attributes to be serialized using #as_json
      #
      def extract_serializable_attributes(options = {})
        opts = options.try(:dup) || {}
        only = Array.wrap(opts[:only]).map(&:to_s)

        only = if only.blank?
                 client_serializable_attributes
               else
                 only & client_serializable_attributes
               end

        only -= Array.wrap(opts[:except]).map(&:to_s) if opts.key?(:except)
        only.uniq
      end

      # Collection of attributes that could be serialized for public.
      # Override this method if you need additional attributes to be serialized.
      #
      # @return [Array<String>] collection of serializable attributes
      #
      # NOTE: `serializable_attributes` method already taken by Rails >= 6
      #
      def client_serializable_attributes
        attributes = %w[id name created_at]
        attributes << "uid" unless confidential?
        attributes
      end
    end

    module ClassMethods
      # Returns Applications associated with active (not revoked) Access Tokens
      # that are owned by the specific Resource Owner.
      #
      # @param resource_owner [ActiveRecord::Base]
      #   Resource Owner model instance
      #
      # @return [ActiveRecord::Relation]
      #   Applications authorized for the Resource Owner
      #
      def authorized_for(resource_owner)
        resource_access_tokens = Doorkeeper.config.access_token_model.active_for(resource_owner)
        where(id: resource_access_tokens.select(:application_id).distinct)
      end

      # Revokes AccessToken and AccessGrant records that have not been revoked and
      # associated with the specific Application and Resource Owner.
      #
      # @param resource_owner [ActiveRecord::Base]
      #   instance of the Resource Owner model
      #
      def revoke_tokens_and_grants_for(id, resource_owner)
        Doorkeeper.config.access_token_model.revoke_all_for(id, resource_owner)
        Doorkeeper.config.access_grant_model.revoke_all_for(id, resource_owner)
      end

      private

      def compute_doorkeeper_table_name
        table_name = "oauth_application"
        table_name = table_name.pluralize if pluralize_table_names
        "#{table_name_prefix}#{table_name}#{table_name_suffix}"
      end
    end
  end
end
