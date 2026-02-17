# frozen_string_literal: true

shared_context "valid token", token: :valid do
  let(:token_string) { "1A2B3C4D" }

  let :token do
    double(
      Doorkeeper::AccessToken,
      accessible?: true, includes_scope?: true, acceptable?: true,
      previous_refresh_token: "", revoke_previous_refresh_token!: true,
      uses_dpop?: false,
    )
  end

  before do
    allow(
      Doorkeeper::AccessToken,
    ).to receive(:by_token).with(token_string).and_return(token)
  end
end

shared_context "invalid token", token: :invalid do
  let(:token_string) { "1A2B3C4D" }

  let :token do
    double(
      Doorkeeper::AccessToken,
      accessible?: false, revoked?: false, expired?: false,
      includes_scope?: false, acceptable?: false,
      previous_refresh_token: "", revoke_previous_refresh_token!: true,
      uses_dpop?: false,
    )
  end

  before do
    allow(
      Doorkeeper::AccessToken,
    ).to receive(:by_token).with(token_string).and_return(token)
  end
end

shared_context "expired token", token: :expired do
  let :token_string do
    "1A2B3C4DEXP"
  end

  let :token do
    double(
      Doorkeeper::AccessToken,
      accessible?: false, revoked?: false, expired?: true,
      includes_scope?: false, acceptable?: false,
      previous_refresh_token: "", revoke_previous_refresh_token!: true,
      uses_dpop?: false,
    )
  end

  before do
    allow(
      Doorkeeper::AccessToken,
    ).to receive(:by_token).with(token_string).and_return(token)
  end
end

shared_context "revoked token", token: :revoked do
  let :token_string do
    "1A2B3C4DREV"
  end

  let :token do
    double(
      Doorkeeper::AccessToken,
      accessible?: false, revoked?: true, expired?: false,
      includes_scope?: false, acceptable?: false,
      previous_refresh_token: "", revoke_previous_refresh_token!: true,
      uses_dpop?: false,
    )
  end

  before do
    allow(
      Doorkeeper::AccessToken,
    ).to receive(:by_token).with(token_string).and_return(token)
  end
end

shared_context "forbidden token", token: :forbidden do
  let :token_string do
    "1A2B3C4DFORB"
  end

  let :token do
    double(
      Doorkeeper::AccessToken,
      accessible?: true, includes_scope?: true, acceptable?: false,
      previous_refresh_token: "", revoke_previous_refresh_token!: true,
      uses_dpop?: false,
    )
  end

  before do
    allow(
      Doorkeeper::AccessToken,
    ).to receive(:by_token).with(token_string).and_return(token)
  end
end

shared_context "dpop token", token: :dpop do
  let(:jkt) { JWT::JWK::Thumbprint.new(JWT::JWK.new(signing_key)).generate }
  let(:signing_key) { OpenSSL::PKey::EC.generate("prime256v1") }

  let(:token_string) { "1A2B3C4D" }
  let(:token) { FactoryBot.create(:access_token, token: token_string, dpop_jkt: jkt) }

  before do
    allow(Doorkeeper::AccessToken).to receive(:by_token).with(token_string).and_return(token)
  end
end
