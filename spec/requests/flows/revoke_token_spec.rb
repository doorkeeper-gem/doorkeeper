require 'spec_helper_integration'

describe 'Revoke Token Flow' do
  before do
    Doorkeeper.configure { orm DOORKEEPER_ORM }
  end

  context 'with default parameters' do
    let(:client_application) { FactoryGirl.create :application }
    let(:resource_owner) { User.create!(name: 'John', password: 'sekret') }
    let(:authorization_access_token) do
      FactoryGirl.create(:access_token,
                         application: client_application,
                         resource_owner_id: resource_owner.id,
                         use_refresh_token: true)
    end
    let(:headers) { { 'HTTP_AUTHORIZATION' => "Bearer #{authorization_access_token.token}" } }

    context 'With invalid token to revoke' do
      it 'client wants to revoke the given access token' do
        post revocation_token_endpoint_url, { token: 'I_AM_AN_INVALIDE_TOKEN' }, headers

        authorization_access_token.reload
        # The authorization server responds with HTTP status code 200 if the token
        # has been revoked successfully or if the client submitted an invalid token.
        expect(response).to be_success
        expect(authorization_access_token).to_not be_revoked
      end
    end

    context 'The access token to revoke is the same than the authorization access token' do
      let(:token_to_revoke) { authorization_access_token }

      it 'client wants to revoke the given access token' do
        post revocation_token_endpoint_url, { token: token_to_revoke.token }, headers

        token_to_revoke.reload
        authorization_access_token.reload

        expect(response).to be_success
        expect(token_to_revoke.revoked?).to be_truthy
        expect(Doorkeeper::AccessToken.by_refresh_token(token_to_revoke.refresh_token).revoked?).to be_truthy
      end

      it 'client wants to revoke the given access token using the POST query string' do
        url_with_query_string = revocation_token_endpoint_url + '?' + Rack::Utils.build_query(token: token_to_revoke.token)
        post url_with_query_string, {}, headers

        token_to_revoke.reload
        authorization_access_token.reload

        expect(response).to be_success
        expect(token_to_revoke.revoked?).to be_falsey
        expect(Doorkeeper::AccessToken.by_refresh_token(token_to_revoke.refresh_token).revoked?).to be_falsey
        expect(authorization_access_token.revoked?).to be_falsey
      end
    end

    context 'The access token to revoke app and owners are the same than the authorization access token' do
      let(:token_to_revoke) do
        FactoryGirl.create(:access_token,
                           application: client_application,
                           resource_owner_id: resource_owner.id,
                           use_refresh_token: true)
      end

      it 'client wants to revoke the given access token' do
        post revocation_token_endpoint_url, { token: token_to_revoke.token }, headers

        token_to_revoke.reload
        authorization_access_token.reload

        expect(response).to be_success
        expect(token_to_revoke.revoked?).to be_truthy
        expect(Doorkeeper::AccessToken.by_refresh_token(token_to_revoke.refresh_token).revoked?).to be_truthy
        expect(authorization_access_token.revoked?).to be_falsey
      end
    end

    context 'The access token to revoke authorization owner is the same than the authorization access token' do
      let(:other_client_application) { FactoryGirl.create :application }
      let(:token_to_revoke) do
        FactoryGirl.create(:access_token,
                           application: other_client_application,
                           resource_owner_id: resource_owner.id,
                           use_refresh_token: true)
      end

      it 'client wants to revoke the given access token' do
        post revocation_token_endpoint_url, { token: token_to_revoke.token }, headers

        token_to_revoke.reload
        authorization_access_token.reload

        expect(response).to be_success
        expect(token_to_revoke.revoked?).to be_falsey
        expect(Doorkeeper::AccessToken.by_refresh_token(token_to_revoke.refresh_token).revoked?).to be_falsey
        expect(authorization_access_token.revoked?).to be_falsey
      end
    end

    context 'The access token to revoke app is the same than the authorization access token' do
      let(:other_resource_owner) { User.create!(name: 'Matheo', password: 'pareto') }
      let(:token_to_revoke) do
        FactoryGirl.create(:access_token,
                           application: client_application,
                           resource_owner_id: other_resource_owner.id,
                           use_refresh_token: true)
      end

      it 'client wants to revoke the given access token' do
        post revocation_token_endpoint_url, { token: token_to_revoke.token }, headers

        token_to_revoke.reload
        authorization_access_token.reload

        expect(response).to be_success
        expect(token_to_revoke.revoked?).to be_falsey
        expect(Doorkeeper::AccessToken.by_refresh_token(token_to_revoke.refresh_token).revoked?).to be_falsey
        expect(authorization_access_token.revoked?).to be_falsey
      end
    end

    context 'With valid refresh token to revoke' do
      let(:token_to_revoke) do
        FactoryGirl.create(:access_token,
                           application: client_application,
                           resource_owner_id: resource_owner.id,
                           use_refresh_token: true)
      end

      it 'client wants to revoke the given refresh token' do
        post revocation_token_endpoint_url, { token: token_to_revoke.refresh_token, token_type_hint: 'refresh_token' }, headers
        authorization_access_token.reload
        token_to_revoke.reload

        expect(response).to be_success
        expect(Doorkeeper::AccessToken.by_refresh_token(token_to_revoke.refresh_token).revoked?).to be_truthy
        expect(authorization_access_token).to_not be_revoked
      end
    end
  end
end
