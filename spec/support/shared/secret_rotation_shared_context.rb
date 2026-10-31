# frozen_string_literal: true

shared_context "with client secret rotation" do
  def enable_rotation
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      enable_secret_rotation
    end
  end

  # Seeds the columns the way a rotation writes them, without going through
  # the writer: the current secret moves to `old_secret` and a fresh one is
  # generated. Returns the superseded plain text secret.
  def retain_current_secret(application)
    old_plaintext = application.plaintext_secret
    application.update_columns(old_secret: application.secret, old_secret_created_at: Time.now.utc)
    application.renew_secret
    application.save!
    old_plaintext
  end

  # A COMMIT lost to ConnectionFailed (Rails 7.1+): savepoint rolled back, connection kept.
  def lose_commit(connection)
    allow(connection).to receive(:release_savepoint).and_wrap_original do |_original, name|
      connection.rollback_to_savepoint(name)
      raise ::ActiveRecord::ConnectionFailed, "lost during COMMIT"
    end
    allow(connection).to receive(:throw_away!)
  end

  # Reset the once-per-process warning flag: `column_names` stubs are undone per example, it is not.
  after do
    if Doorkeeper::Application.instance_variable_defined?(:@secret_rotation_columns_warned)
      Doorkeeper::Application.remove_instance_variable(:@secret_rotation_columns_warned)
    end
  end
end
