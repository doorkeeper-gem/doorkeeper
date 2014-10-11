require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe PreAuthorization do
    let(:config) {
      config = Doorkeeper.configuration
      config.stub(:default_scopes) { Scopes.new }
      config.stub(:scopes) { Scopes.from_string('public') }
      config
    }

    let(:resource_owner) { double :resource_owner }

    let(:server) { double :server, current_resource_owner: resource_owner }

    let(:client) { double :client, redirect_uri: 'http://tst.com/auth' }

    let :attributes do
      {
        response_type: 'code',
        redirect_uri: 'http://tst.com/auth',
        state: 'save-this'
      }
    end

    subject do
      PreAuthorization.new(config, server, client, attributes)
    end

    it 'is authorizable when request is valid' do
      expect(subject).to be_authorizable
    end

    it 'accepts code as response type' do
      subject.response_type = 'code'
      expect(subject).to be_authorizable
    end

    it 'accepts token as response type' do
      subject.response_type = 'token'
      expect(subject).to be_authorizable
    end

    context 'when using default grant flows' do
      it 'accepts "code" as response type' do
        subject.response_type = 'code'
        expect(subject).to be_authorizable
      end

      it 'accepts "token" as response type' do
        subject.response_type = 'token'
        expect(subject).to be_authorizable
      end
    end

    context 'when authorization code grant flow is disabled' do
      before do
        config.stub(:grant_flows) { ['implicit'] }
      end

      it 'does not accept "code" as response type' do
        subject.response_type = 'code'
        expect(subject).not_to be_authorizable
      end
    end

    context 'when implicit grant flow is disabled' do
      before do
        config.stub(:grant_flows) { ['authorization_code'] }
      end

      it 'does not accept "token" as response type' do
        subject.response_type = 'token'
        expect(subject).not_to be_authorizable
      end
    end

    it 'accepts valid scopes' do
      subject.scope = 'public'
      expect(subject).to be_authorizable
    end

    it 'uses default scopes when none is required' do
      allow(config).to receive(:default_scopes).and_return(Scopes.from_string('default'))
      subject.scope = nil
      expect(subject.scope).to  eq('default')
      expect(subject.scopes).to eq(Scopes.from_string('default'))
    end

    it 'accepts test uri' do
      subject.redirect_uri = 'urn:ietf:wg:oauth:2.0:oob'
      expect(subject).to be_authorizable
    end

    it 'matches the redirect uri against client\'s one' do
      subject.redirect_uri = 'http://nothesame.com'
      expect(subject).not_to be_authorizable
    end

    it 'stores the state' do
      expect(subject.state).to eq('save-this')
    end

    it 'rejects if response type is not allowed' do
      subject.response_type = 'whops'
      expect(subject).not_to be_authorizable
    end

    it 'requires an existing client' do
      subject.client = nil
      expect(subject).not_to be_authorizable
    end

    it 'requires a redirect uri' do
      subject.redirect_uri = nil
      expect(subject).not_to be_authorizable
    end

    it 'rejects non-valid scopes' do
      subject.scope = 'invalid'
      expect(subject).not_to be_authorizable
    end

    context 'when custom validation provided' do
      before do
        @args = {}
        validation = Proc.new { |validator, owner, client, scopes|
          @args[:owner] = owner
          @args[:client] = client
          @args[:scopes] = scopes

          validator.error = @given_error
          @result
        }
        config.stub(:validate_on_authorize) { validation }
      end

      it 'is passed correct params' do
        subject.scope = 'public write'
        subject.authorizable?
        expect(@args[:owner]).to eq(resource_owner)
        expect(@args[:client]).to eq(client)
        expect(@args[:scopes]).to eq(['public', 'write'])
      end

      it 'accepts when validation succeeds' do
        @result = true
        expect(subject).to be_authorizable
      end

      it 'accepts when validation returns nil' do
        @result = nil
        expect(subject).to be_authorizable
      end

      it 'rejects when validation fails' do
        @result = false
        expect(subject).not_to be_authorizable
        expect(subject.error).to eq(:invalid_scope)
      end

      it 'rejects when validation sets error' do
        @result = true
        @given_error = :foo_bar
        expect(subject).not_to be_authorizable
        expect(subject.error).to eq(:foo_bar)
      end
    end
  end
end
