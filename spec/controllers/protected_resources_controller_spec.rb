require 'spec_helper_integration'

module ControllerActions
  def index
    render text: 'index'
  end

  def show
    render text: 'show'
  end
end

shared_examples 'specified for particular actions' do
  context 'with valid token', token: :valid do
    it 'allows into index action' do
      get :index, access_token: token_string
      expect(response).to be_success
    end

    it 'allows into show action' do
      get :show, id: '3', access_token: token_string
      expect(response).to be_success
    end
  end

  context 'with invalid token', token: :invalid do
    include_context 'invalid token'

    it 'does not allow into index action' do
      get :index, access_token: token_string
      expect(response.status).to eq 401
      expect(response.headers['WWW-Authenticate']).to match(/^Bearer/)
    end

    it 'allows into show action' do
      get :show, id: '5', access_token: token_string
      expect(response).to be_success
    end
  end
end

shared_examples 'specified with except' do
  context 'with valid token', token: :valid do
    it 'allows into index action' do
      get :index, access_token: token_string
      expect(response).to be_success
    end

    it 'allows into show action' do
      get :show, id: '4', access_token: token_string
      expect(response).to be_success
    end
  end

  context 'with invalid token', token: :invalid do
    it 'allows into index action' do
      get :index, access_token: token_string
      expect(response).to be_success
    end

    it 'does not allow into show action' do
      get :show, id: '14', access_token: token_string
      expect(response.status).to eq 401
      expect(response.headers['WWW-Authenticate']).to match(/^Bearer/)
    end
  end
end

describe 'Doorkeeper_for helper' do
  context 'accepts token code specified as' do
    controller do
      doorkeeper_for :all

      def index
        render text: 'index'
      end
    end

    let(:token_string) { '1A2BC3' }
    let(:token) do
      double(Doorkeeper::AccessToken, acceptable?: true)
    end

    it 'access_token param' do
      expect(Doorkeeper::AccessToken).to receive(:authenticate).with(token_string).and_return(token)
      get :index, access_token: token_string
    end

    it 'bearer_token param' do
      expect(Doorkeeper::AccessToken).to receive(:authenticate).with(token_string).and_return(token)
      get :index, bearer_token: token_string
    end

    it 'Authorization header' do
      expect(Doorkeeper::AccessToken).to receive(:authenticate).with(token_string).and_return(token)
      request.env['HTTP_AUTHORIZATION'] = "Bearer #{token_string}"
      get :index
    end

    it 'different kind of Authorization header' do
      expect(Doorkeeper::AccessToken).not_to receive(:authenticate)
      request.env['HTTP_AUTHORIZATION'] = "MAC #{token_string}"
      get :index
    end

    it 'does not change Authorization header value' do
      expect(Doorkeeper::AccessToken).to receive(:authenticate).exactly(2).times.and_return(token)
      request.env['HTTP_AUTHORIZATION'] = "Bearer #{token_string}"
      get :index
      controller.send(:remove_instance_variable, :@token)
      get :index
    end
  end

  context 'defined for all actions' do
    controller do
      doorkeeper_for :all

      include ControllerActions
    end

    context 'with valid token', token: :valid do
      it 'allows into index action' do
        get :index, access_token: token_string
        expect(response).to be_success
      end

      it 'allows into show action' do
        get :show, id: '4', access_token: token_string
        expect(response).to be_success
      end
    end

    context 'with invalid token', token: :invalid do
      it 'does not allow into index action' do
        get :index, access_token: token_string
        expect(response.status).to eq 401
        expect(response.header['WWW-Authenticate']).to match(/^Bearer/)
      end

      it 'does not allow into show action' do
        get :show, id: '4', access_token: token_string
        expect(response.status).to eq 401
        expect(response.header['WWW-Authenticate']).to match(/^Bearer/)
      end
    end
  end

  context 'defined only for index action' do
    controller do
      doorkeeper_for :index

      include ControllerActions
    end
    include_examples 'specified for particular actions'
  end

  context 'defined for actions except index' do
    controller do
      doorkeeper_for :all, except: :index

      include ControllerActions
    end
    include_examples 'specified with except'
  end

  context 'defined with scopes' do
    controller do
      doorkeeper_for :all, scopes: [:write]

      include ControllerActions
    end

    let(:token_string) { '1A2DUWE' }

    it 'allows if the token has particular scopes' do
      token = double(Doorkeeper::AccessToken, accessible?: true, scopes: %w(write public))
      expect(token).to receive(:acceptable?).with(['write']).and_return(true)
      expect(Doorkeeper::AccessToken).to receive(:authenticate).with(token_string).and_return(token)
      get :index, access_token: token_string
      expect(response).to be_success
    end

    it 'does not allow if the token does not include given scope' do
      token = double(Doorkeeper::AccessToken, accessible?: true, scopes: ['public'], revoked?: false, expired?: false)
      expect(Doorkeeper::AccessToken).to receive(:authenticate).with(token_string).and_return(token)
      expect(token).to receive(:acceptable?).with(['write']).and_return(false)
      get :index, access_token: token_string
      expect(response.status).to eq 403
      expect(response.header).to_not include('WWW-Authenticate')
    end
  end

  context 'when custom unauthorized render options are configured' do
    controller do
      doorkeeper_for :all

      include ControllerActions
    end

    context 'with a JSON custom render', token: :invalid do
      before do
        expect(controller).to receive(:doorkeeper_unauthorized_render_options).and_return(json: ActiveSupport::JSON.encode(error: 'Unauthorized'))
      end

      it 'it renders a custom JSON response', token: :invalid do
        get :index, access_token: token_string
        expect(response.status).to eq 401
        expect(response.content_type).to eq('application/json')
        expect(response.header['WWW-Authenticate']).to match(/^Bearer/)
        parsed_body = JSON.parse(response.body)
        expect(parsed_body).not_to be_nil
        expect(parsed_body['error']).to eq('Unauthorized')
      end

    end

    context 'with a text custom render', token: :invalid do
      before do
        expect(controller).to receive(:doorkeeper_unauthorized_render_options).and_return(text: 'Unauthorized')
      end

      it 'it renders a custom JSON response', token: :invalid do
        get :index, access_token: token_string
        expect(response.status).to eq 401
        expect(response.content_type).to eq('text/html')
        expect(response.header['WWW-Authenticate']).to match(/^Bearer/)
        expect(response.body).to eq('Unauthorized')
      end
    end
  end

  context 'when defined with conditional if block' do
    controller do
      doorkeeper_for :index, if: -> { the_false }
      doorkeeper_for :show,  if: -> { the_true }

      include ControllerActions

      private

      def the_true
        true
      end

      def the_false
        false
      end
    end

    context 'with valid token', token: :valid do
      it 'enables access if passed block evaluates to false' do
        get :index, access_token: token_string
        expect(response).to be_success
      end

      it 'enables access if passed block evaluates to true' do
        get :show, id: 1, access_token: token_string
        expect(response).to be_success
      end
    end

    context 'with invalid token', token: :invalid do
      it 'enables access if passed block evaluates to false' do
        get :index, access_token: token_string
        expect(response).to be_success
      end

      it 'does not enable access if passed block evaluates to true' do
        get :show, id: 3, access_token: token_string
        expect(response.status).to eq 401
        expect(response.header['WWW-Authenticate']).to match(/^Bearer/)
      end
    end
  end

  context 'when defined with conditional unless block' do
    controller do
      doorkeeper_for :index, unless: -> { the_false }
      doorkeeper_for :show, unless: -> { the_true }

      include ControllerActions

      def the_true
        true
      end

      private

      def the_false
        false
      end
    end

    context 'with valid token', token: :valid do
      it 'allows access if passed block evaluates to false' do
        get :index, access_token: token_string
        expect(response).to be_success
      end

      it 'allows access if passed block evaluates to true' do
        get :show, id: 1, access_token: token_string
        expect(response).to be_success
      end
    end

    context 'with invalid token', token: :invalid do
      it 'does not allow access if passed block evaluates to false' do
        get :index, access_token: token_string
        expect(response.status).to eq 401
        expect(response.header['WWW-Authenticate']).to match(/^Bearer/)
      end

      it 'allows access if passed block evaluates to true' do
        get :show, id: 3, access_token: token_string
        expect(response).to be_success
      end
    end
  end
end
