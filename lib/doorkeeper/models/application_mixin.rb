# frozen_string_literal: true

module Doorkeeper
  module ApplicationMixin
    extend ActiveSupport::Concern

    include OAuth::Helpers
    include Models::Concerns::WriteToPrimary
    include Models::Orderable
    include Models::SecretStorable
    include Models::Scopes

    # :nodoc
    module ClassMethods
      # Returns an instance of the Doorkeeper::Application with
      # specific UID and secret.
      #
      # Public/Non-confidential applications will only find by uid if secret is
      # blank.
      #
      # @param uid [#to_s] UID (any object that responds to `#to_s`)
      # @param secret [#to_s] secret (any object that responds to `#to_s`)
      #
      # @return [Doorkeeper::Application, nil]
      #   Application instance or nil if there is no record with such credentials
      #
      def by_uid_and_secret(uid, secret)
        app = by_uid(uid)
        return unless app
        return app if secret.blank? && !app.confidential?

        app if app.secret_matches?(secret)
      end

      # Returns an instance of the Doorkeeper::Application with specific UID.
      #
      # @param uid [#to_s] UID (any object that responds to `#to_s`)
      #
      # @return [Doorkeeper::Application, nil] Application instance or nil
      #   if there is no record with such UID
      #
      def by_uid(uid)
        find_by(uid: uid.to_s)
      end

      ##
      # Determines the secret storing transformer
      # Unless configured otherwise, uses the plain secret strategy
      def secret_strategy
        ::Doorkeeper.config.application_secret_strategy
      end

      ##
      # Determine the fallback storing strategy
      # Unless configured, there will be no fallback
      def fallback_secret_strategy
        ::Doorkeeper.config.application_secret_fallback_strategy
      end

      # Whether a superseded client secret is retained and keeps
      # authenticating the client for a grace period.
      #
      # Both halves are required: the `enable_secret_rotation` option opts the
      # server in, and the `old_secret` / `old_secret_created_at` columns are
      # where the superseded secret and the date it was retained live. Reading
      # the columns rather than assuming them (as `pkce_supported?` does for
      # `code_challenge`) means enabling the option without running the
      # migration leaves authentication behaving exactly as it did before,
      # instead of raising on every token request. Both are checked because a
      # rotation writes both: a half-applied migration is no more usable than
      # none at all, and failing the check is how it stays a no-op rather
      # than an error on the first `#rotate_secret!`.
      #
      # @return [Boolean]
      #
      def secret_rotation_enabled?
        return false unless Doorkeeper.config.enable_secret_rotation?
        return true if secret_rotation_columns?

        warn_missing_secret_rotation_columns
        false
      end

      # Whether the columns a rotation writes are there, without asking
      # whether the option that writes them is on.
      #
      # The half of the check that ending a grace period goes on: turning
      # `enable_secret_rotation` off stops a retained secret authenticating
      # but does not remove it, so the row goes on holding a live credential
      # that comes back into service the moment the option does. Dropping it
      # must not require re-arming the feature for every application on the
      # server first, so +#clear_old_secret!+ asks this and +#rotate_secret!+
      # asks the one above.
      #
      # @return [Boolean]
      #
      def secret_rotation_columns?
        column_names.include?("old_secret") && column_names.include?("old_secret_created_at")
      end

      private

      # Enabling the option without running the migration is deliberately not
      # an error: client authentication carries on exactly as it did before.
      # But it is also entirely silent, so the first sign of it would be a
      # `SecretRotationNotEnabled` from whichever console session or job first
      # calls `#rotate_secret!`. Said once per process instead, here rather
      # than from a boot hook: the columns are read off the schema, which is a
      # database read, and a boot hook asking for them would open a connection
      # during tasks that have no database to open one to (`assets:precompile`
      # and friends) and wait through its retries before finding that out.
      # Here the schema has already been loaded by the caller's own lookup.
      #
      # Set before the write so that a logger raising cannot turn the warning
      # into one per authentication, and not synchronised: two threads racing
      # the first lookup cost a duplicate line, which is cheaper than a lock on
      # a path every client authentication takes.
      def warn_missing_secret_rotation_columns
        return if @secret_rotation_columns_warned
        return unless defined?(::Rails) && ::Rails.logger

        @secret_rotation_columns_warned = true
        ::Rails.logger.warn(
          "[DOORKEEPER] enable_secret_rotation is set, but #{name} has no " \
          "old_secret / old_secret_created_at columns: client authentication is unchanged and " \
          "Application#rotate_secret! raises SecretRotationNotEnabled. Run " \
          "`rails generate doorkeeper:secret_rotation` and apply the migration.",
        )
      end
    end

    # Set an application's valid redirect URIs.
    #
    # @param uris [String, Array<String>] Newline-separated string or array the URI(s)
    #
    # @return [String] The redirect URI(s) separated by newlines.
    #
    def redirect_uri=(uris)
      super(uris.is_a?(Array) ? uris.join("\n") : uris)
    end

    # Check whether the given plain text secret matches our stored secret
    #
    # @param input [#to_s] Plain secret provided by user
    #        (any object that responds to `#to_s`)
    #
    # @return [Boolean] Whether the given secret matches the stored secret
    #                of this application.
    #
    # @note When the secret matches only via the fallback strategy, the stored
    #       secret is upgraded to the active strategy as a side-effect (mirrors
    #       the find_by_plaintext_token -> find_by_fallback_token pattern).
    #
    def secret_matches?(input)
      # return false if either is nil, since secure_compare depends on strings
      # but Application secrets MAY be nil depending on confidentiality.
      return false if input.nil? || secret.nil?

      input = input.to_s

      return stored_secret_matches?(input, :secret) unless self.class.secret_rotation_enabled?

      # Both comparisons are performed and only then combined. Returning as
      # soon as the current secret matches would make a successful
      # authentication measurably cheaper than a failed one by exactly the cost
      # of one comparison — which under bcrypt is the dominant cost of the
      # request — so the shape of the work stays the same either way.
      match = stored_secret_matches?(input, :secret)
      old_match = old_secret_matches?(input)

      # Reported only when the old secret is what actually let the client in,
      # so that an application can tell whether anyone still depends on it
      # before ending the grace period. This runs on a successful
      # authentication only — a caller that cannot produce either secret never
      # reaches it, so it adds no signal an attacker can measure.
      Doorkeeper.config.after_old_secret_used.call(self) if old_match && !match

      match || old_match
    end

    # Check whether the given plain text secret matches the secret superseded
    # by the last rotation (see +#rotate_secret!+).
    #
    # A comparison runs even when there is no retained secret to compare
    # against — because none is stored, or because the one that is has
    # outlived its grace period — against the current secret, with the result
    # discarded, so that whether this client is midway through a rotation
    # cannot be read off how long the endpoint took to answer. The dummy
    # comparison is deliberately made against a real stored secret rather than
    # a constant, so that it costs what a genuine comparison costs — which it
    # does whenever both columns were written by the same strategy. A rotation
    # sees to that: it re-derives a secret the fallback strategy wrote before
    # retaining it, so that the two columns do not end up in different formats
    # (see the Active Record mixin's #retainable_secret).
    #
    # What it cannot equalise is a format a rotation had no way to re-derive
    # from — a fallback strategy that hashes, so that no plaintext survives
    # to hash again under the active one. A `secret` and an `old_secret`
    # written by different strategies then cost different comparisons, and the
    # difference is measurable by anyone: under bcrypt an `InvalidHash` is
    # refused for its shape before any work factor applies. Retire such a
    # fallback — which is what a fallback is for — before rotating under it.
    #
    # What remains once the formats agree is the *active* strategy's work.
    # With a fallback strategy configured, a rotated application costs one
    # comparison more than an unrotated one on a **successful**
    # authentication: the dummy comparison matches on the active strategy and
    # stops there, while the genuine comparison against a stored `old_secret`
    # the request does not hold misses it and goes on to the fallback. Both
    # built-in fallbacks make that comparison cheap — `Plain` is a
    # `secure_compare`, and `BCrypt` raises `InvalidHash` on a value it did
    # not write, before any work factor is applied — and only a caller
    # already holding a valid secret gets to measure it. A custom fallback
    # with a real work factor that does not refuse foreign formats outright
    # would make the difference visible to such a caller.
    #
    # @param input [#to_s] Plain secret provided by user
    #        (any object that responds to `#to_s`)
    #
    # @return [Boolean] Whether the given secret matches the old secret
    #                of this application.
    #
    def old_secret_matches?(input)
      return false if input.nil? || !self.class.secret_rotation_enabled?

      rotated = old_secret.present?
      # Nothing to compare against, and nothing to hide either: an application
      # with no secret at all is a public client, whose secret is never
      # checked. Asked of the current secret and not of `old_secret`, so that
      # this half answers what +#secret_matches?+ answers: that one refuses a
      # nil `secret` before it ever consults the retained one, and a host
      # calling this predicate to learn which secret a client presented would
      # otherwise be told the old one authenticated a request Doorkeeper had
      # rejected. No timing to equalise on the way out: +#secret_matches?+
      # never reaches here for such an application, so the only caller is a
      # host asking directly.
      return false if secret.nil?

      # Read before the comparison rather than after it, so the comparison can
      # be pointed away from a credential this server has already declared
      # dead. Expiry reads two columns the caller cannot influence, so nothing
      # about it is measurable.
      expired = old_secret_expired?

      matched =
        if rotated && !expired
          stored_secret_matches?(input.to_s, :old_secret)
        else
          # The dummy comparison, made with the fallback upgrade suppressed:
          # it is asked only to cost what a real comparison costs, and must
          # write nothing. Letting it keep the upgrade would have a question
          # about the *superseded* secret rewrite the current one, would
          # re-encode a secret whose grace period has already ended on an
          # authentication that is about to be rejected, and — inside
          # +#secret_matches?+, where the genuine comparison has already
          # upgraded — would issue a second write whenever the first lost the
          # conditional-write race.
          stored_secret_matches?(input.to_s, :secret, upgrade: false)
        end

      # Exactly one comparison has run on every path, so combining the three
      # here costs the same whichever one it was.
      rotated && matched && !expired
    end

    # Whether the retained secret has outlived the configured
    # `secret_rotation_grace_period`. Always false when no grace period is
    # configured, which is the default: the grace period then ends only when
    # the application calls +#clear_old_secret!+. Also false when nothing is
    # retained — an application that never rotated has no grace period to
    # outlive.
    #
    # An old secret with no +old_secret_created_at+ is treated as expired
    # rather than as ageless. Every rotation records the timestamp, so a
    # missing one means the column was written by something other than
    # +#rotate_secret!+ — and honouring a deadline nobody can date would leave
    # exactly the indefinitely-valid secret the option was configured to
    # prevent.
    #
    # Expiring an old secret stops it authenticating; it does not remove it.
    # Use +#clear_old_secret!+ for that.
    #
    # Guarded like +#old_secret_matches?+, and for the same reason: without
    # the migration there is no +old_secret+ to read, and a rotation feature
    # that was never enabled should answer rather than raise. The mutating
    # APIs raise +SecretRotationNotEnabled+ instead, because a caller asking
    # to rotate a secret the server cannot store needs to be told why.
    #
    # @return [Boolean]
    #
    def old_secret_expired?
      return false unless self.class.secret_rotation_enabled?

      grace_period = Doorkeeper.config.secret_rotation_grace_period
      return false if grace_period.nil? || old_secret.blank?
      return true if old_secret_created_at.blank?

      old_secret_created_at + grace_period < Time.now.utc
    end

    private

    # Compare +input+ against the secret stored in +attribute+, honouring the
    # configured fallback strategy the same way the primary secret always has.
    #
    # @param input [String] Plain secret provided by user
    # @param attribute [Symbol] the secret attribute to compare against
    # @param upgrade [Boolean] whether a fallback match rewrites the stored
    #        value in the active strategy's format. Off for a comparison whose
    #        result is discarded (see +#old_secret_matches?+), which must cost
    #        what a real one costs without writing anything.
    #
    # @return [Boolean]
    #
    def stored_secret_matches?(input, attribute, upgrade: true)
      stored = public_send(attribute)

      # When matching the secret by comparer function, all is well.
      return true if secret_strategy.secret_matches?(input, stored)

      # When fallback lookup is enabled, ensure applications with plain secrets
      # can still be found, upgrading the stored secret to the active strategy
      # on a successful match.
      if fallback_secret_strategy&.secret_matches?(input, stored)
        self.class.upgrade_fallback_value(self, attribute, input) if upgrade
        true
      else
        false
      end
    end
  end
end
