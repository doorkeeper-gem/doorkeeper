# frozen_string_literal: true

shared_context 'with token hashing enabled' do
  let(:hashed_or_plain_token_func) do
    Doorkeeper::SecretStoring::Sha256Hash.method(:transform_secret)
  end

  before do
    Doorkeeper.configure do
      hash_token_secrets
    end
  end
end

shared_context 'with token hashing and fallback lookup enabled' do
  let(:hashed_or_plain_token_func) do
    Doorkeeper::SecretStoring::Sha256Hash.method(:transform_secret)
  end

  before do
    Doorkeeper.configure do
      hash_token_secrets fallback: :plain
    end
  end
end

shared_context 'with application hashing enabled' do
  let(:hashed_or_plain_token_func) do
    Doorkeeper::SecretStoring::Sha256Hash.method(:transform_secret)
  end
  before do
    Doorkeeper.configure do
      hash_application_secrets
    end
  end
end
