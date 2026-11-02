# frozen_string_literal: true

# Out-of-band redirect URIs are refused by default and the native route is not
# drawn; this enables both for the example.
shared_context "with oob redirect uris allowed" do
  around do |example|
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      allow_oob_redirect_uris true
    end
    Rails.application.reload_routes!

    example.run
  ensure
    Doorkeeper.configure { orm DOORKEEPER_ORM }
    Rails.application.reload_routes!
  end

  before { config_is_set(:allow_oob_redirect_uris, true) }
end
