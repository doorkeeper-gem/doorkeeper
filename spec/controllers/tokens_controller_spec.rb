require 'spec_helper_integration'

describe Doorkeeper::TokensController do
  describe 'when authorization has succeeded' do
    let :token do
      double(:token, authorize: true)
    end

    before do
      allow(controller).to receive(:token) { token }
    end

    it 'returns the authorization' do
      skip 'verify need of these specs'

      expect(token).to receive(:authorization)

      post :create
    end
  end

  describe 'when authorization has failed' do
    it 'returns the error response' do
      token = double(:token, authorize: false)
      allow(controller).to receive(:token) { token }

      post :create

      expect(response.status).to eq 401
      expect(response.headers['WWW-Authenticate']).to match(/Bearer/)
    end
  end

  describe 'when there is a failure due to a custom error' do
    it 'returns the error response with a custom message' do
      # NOTE: I18n will look for this key `en.doorkeeper.errors.messages.my_message` in a locale file
      allow(I18n).to receive(:translate).
        with("my_message", hash_including(scope: [:doorkeeper, :errors, :messages])).
        and_return('This is my authorization custom message')

      doorkeeper_error = Doorkeeper::Errors::DoorkeeperError.new('my_message')

      strategy = double(:strategy)
      allow(strategy).to receive(:authorize).and_raise(doorkeeper_error)

      allow(controller).to receive(:server) { double(token_request: strategy) }

      post :create

      expect(response.status).to eq 401
      expect(response.headers['WWW-Authenticate']).to match(/Bearer/)

      expected_response_body = {
        "error"             => "my_message",
        "error_description" => "This is my authorization custom message"
      }

      expect(JSON.load(response.body)).to eq expected_response_body
    end
  end

  describe 'when revoke authorization has failed' do
    # http://tools.ietf.org/html/rfc7009#section-2.2
    it 'returns no error response' do
      token = double(:token, authorize: false)
      allow(controller).to receive(:token) { token }

      post :revoke

      expect(response.status).to eq 200
    end
  end

  describe 'authorize response memoization' do
    it "memoizes the result of the authorization" do
      strategy = double(:strategy, authorize: true)
      expect(strategy).to receive(:authorize).once
      allow(controller).to receive(:strategy) { strategy }
      allow(controller).to receive(:create) do
        controller.send :authorize_response
      end

      post :create
    end
  end
end
