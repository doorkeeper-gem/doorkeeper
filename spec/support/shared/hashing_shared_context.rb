# frozen_string_literal: true

shared_context 'with token hashing enabled' do
  let(:hashed_or_plain_token_func) { Doorkeeper::AccessToken.method(:hashed_or_plain_token) }
  before do
    Doorkeeper.configure do
      hash_token_secrets
    end
  end
end

shared_context 'with token hashing and fallback lookup enabled' do
  let(:hashed_or_plain_token_func) { Doorkeeper::AccessToken.method(:hashed_or_plain_token) }
  before do
    Doorkeeper.configure do
      hash_token_secrets
      fallback_to_plain_secrets
    end
  end
end

shared_context 'with application hashing enabled' do
  let(:hashed_or_plain_token_func) { Doorkeeper::Application.method(:hashed_or_plain_token) }
  before do
    Doorkeeper.configure do
      hash_application_secrets
    end
  end
end

shared_context 'with encryption enabled' do
  let(:hashed_or_plain_token_func) { Doorkeeper::Application.method(:hashed_or_plain_token) }
  before do
    Doorkeeper.configure do
      encrypt_token_secrets
      encryption_key '0c829d3227f04bf8c751bab43fa35ca8925b4615bf18472856e1a004c1081269'
    end
  end
end
