require 'spec_helper_integration'

module ControllerActions
  def index
    render text: 'index'
  end

  def show
    render text: 'show'
  end
end

describe 'doorkeeper authorize filter' do
  context 'accepts token code specified as' do
    controller do
      before_filter :doorkeeper_authorize!

      def index
        render text: 'index'
      end
    end

    let(:token_string) { '1A2BC3' }
    let(:token) do
      double(Doorkeeper::AccessToken, acceptable?: true)
    end

    it 'access_token param' do
      expect(Doorkeeper::AccessToken).to receive(:by_token).with(token_string).and_return(token)
      get :index, access_token: token_string
    end

    it 'bearer_token param' do
      expect(Doorkeeper::AccessToken).to receive(:by_token).with(token_string).and_return(token)
      get :index, bearer_token: token_string
    end

    it 'Authorization header' do
      expect(Doorkeeper::AccessToken).to receive(:by_token).with(token_string).and_return(token)
      request.env['HTTP_AUTHORIZATION'] = "Bearer #{token_string}"
      get :index
    end

    it 'different kind of Authorization header' do
      expect(Doorkeeper::AccessToken).not_to receive(:by_token)
      request.env['HTTP_AUTHORIZATION'] = "MAC #{token_string}"
      get :index
    end

    it 'does not change Authorization header value' do
      expect(Doorkeeper::AccessToken).to receive(:by_token).exactly(2).times.and_return(token)
      request.env['HTTP_AUTHORIZATION'] = "Bearer #{token_string}"
      get :index
      controller.send(:remove_instance_variable, :@_doorkeeper_token)
      get :index
    end
  end

  context 'defined for all actions' do
    controller do
      before_filter :doorkeeper_authorize!

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

  context 'defined with scopes' do
    controller do
      before_filter -> { doorkeeper_authorize! :write }

      include ControllerActions
    end

    let(:token_string) { '1A2DUWE' }

    it 'allows if the token has particular scopes' do
      token = double(Doorkeeper::AccessToken, accessible?: true, scopes: %w(write public))
      expect(token).to receive(:acceptable?).with([:write]).and_return(true)
      expect(Doorkeeper::AccessToken).to receive(:by_token).with(token_string).and_return(token)
      get :index, access_token: token_string
      expect(response).to be_success
    end

    it 'does not allow if the token does not include given scope' do
      token = double(Doorkeeper::AccessToken, accessible?: true, scopes: ['public'], revoked?: false, expired?: false)
      expect(Doorkeeper::AccessToken).to receive(:by_token).with(token_string).and_return(token)
      expect(token).to receive(:acceptable?).with([:write]).and_return(false)
      get :index, access_token: token_string
      expect(response.status).to eq 403
      expect(response.header).to_not include('WWW-Authenticate')
    end
  end

  context 'when custom unauthorized render options are configured' do
    controller do
      before_filter :doorkeeper_authorize!

      include ControllerActions
    end

    context 'with a JSON custom render', token: :invalid do
      before do
        module ControllerActions
          def doorkeeper_unauthorized_render_options(error: nil)
            { json: ActiveSupport::JSON.encode(error_message: error.description) }
          end
        end
      end
      after do
        module ControllerActions
          def doorkeeper_unauthorized_render_options(error: nil)
          end
        end
      end

      it 'it renders a custom JSON response', token: :invalid do
        get :index, access_token: token_string
        expect(response.status).to eq 401
        expect(response.content_type).to eq('application/json')
        expect(response.header['WWW-Authenticate']).to match(/^Bearer/)
        parsed_body = JSON.parse(response.body)
        expect(parsed_body).not_to be_nil
        expect(parsed_body['error_message']).to match('token is invalid')
      end
    end

    context 'with a text custom render', token: :invalid do
      before do
        module ControllerActions
          def doorkeeper_unauthorized_render_options(error: nil)
            { text: 'Unauthorized' }
          end
        end
      end
      after do
        module ControllerActions
          def doorkeeper_unauthorized_render_options(error: nil)
          end
        end
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
end
