# frozen_string_literal: true

module Doorkeeper::Orm::ActiveRecord::Mixins
  # Client secret rotation: the secret superseded by +#rotate_secret!+ is
  # retained in `old_secret` so that it can keep authenticating the client
  # for a grace period. Opening one requires the `enable_secret_rotation`
  # option and the columns the `doorkeeper:secret_rotation` generator adds.
  #
  # Kept in a file of its own rather than in the application mixin: what is
  # written here is a read-modify-write on a live credential under a row
  # lock. Its invariants are easier to hold in view — and to change — when
  # they are not interleaved with the model's validations, associations and
  # serialization.
  #
  # The comparison side of the feature — honouring the retained secret when
  # a client authenticates — belongs in +Doorkeeper::ApplicationMixin+, which
  # every ORM shares, because a stored secret is compared the same way
  # whichever one wrote it.
  module SecretRotation
    extend ActiveSupport::Concern

    # Replaces this application's secret, retaining the superseded one so
    # that clients still presenting it keep authenticating until the
    # application ends the grace period with +#clear_old_secret!+. Requires
    # the `enable_secret_rotation` option and the columns it needs. For a
    # replacement with no grace period, pass +revoke_old: true+ below: with
    # the feature on that is the only call that ends one, since
    # +#renew_secret+ writes the current secret alone and leaves whatever an
    # earlier rotation retained still authenticating.
    #
    # The superseded secret is carried over as *stored*: hashing strategies
    # draw a fresh salt on every write, so the plaintext is not available to
    # store again — and does not need to be, since both columns are written
    # and read back through the same strategy.
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
    #
    # @return [String] new plain text secret value
    #
    def rotate_secret!(revoke_old: false)
      ensure_secret_rotation_enabled!
      ensure_lockable!

      self.class.with_primary_role do
        # Read-modify-write on the row: the secret being retained is the
        # one currently stored, so two rotations racing without a lock
        # would let the later one overwrite a secret the earlier one had
        # already handed to a client — which would then never
        # authenticate. `with_lock` reloads under the lock, so the retained
        # value is the committed one even if this instance was loaded
        # before the other rotation.
        with_lock do
          # A blank `secret` joins `revoke_old` because there is
          # nothing to retain either way: a host schema that relaxed the
          # install migration's `null: false` can hold a public client
          # with no secret at all (see +#secret_required?+). Stamping the
          # timestamp regardless would open a grace period over an empty
          # `old_secret`, leaving the row saying a rotation is midway
          # through when nothing was carried over.
          # `renew_secret` below still writes one, as it always has, so
          # such a client comes out of a rotation holding a secret.
          if revoke_old || secret.blank?
            self.old_secret = nil
            self.old_secret_created_at = nil
          else
            self.old_secret = secret
            self.old_secret_created_at = Time.now.utc
          end

          renew_secret
          save!
        end
      end

      plaintext_secret
    end

    private

    def ensure_secret_rotation_enabled!
      return if self.class.secret_rotation_enabled?

      raise Doorkeeper::Errors::SecretRotationNotEnabled, self.class.table_name
    end

    # `with_lock` gates both of its guarantees on +persisted?+ (Active
    # Record's +#lock!+ does): on a new record it takes no row lock and does
    # not refuse the caller's unsaved changes, so it degenerates to a bare
    # transaction. A rotation there would INSERT whatever else the caller had
    # assigned, and — where they had assigned a secret of their own — retain
    # that plaintext as `old_secret`, creating a row that is already midway
    # through a rotation nobody performed. Both APIs document the opposite,
    # so the case is refused rather than quietly redefined.
    #
    # +persisted?+ is also false for a destroyed record, which saving would
    # not bring back, so that one is told what is actually the matter.
    def ensure_lockable!
      return if persisted?

      remedy = destroyed? ? "the record has been destroyed" : "save the record first"

      raise ::ActiveRecord::RecordNotSaved.new(
        "client secret rotation needs a persisted #{self.class.name}; #{remedy}",
        self,
      )
    end
  end
end
