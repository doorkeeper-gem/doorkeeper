require "spec_helper_integration"

module Doorkeeper::OAuth
  describe PreAuthorization do
    let(:server) { mock :server, :default_scopes => Scopes.new, :scopes => Scopes.from_string('public') }
    let(:client) { mock :client, :redirect_uri => 'http://tst.com/auth' }

    let :attributes do
      {
        :response_type => 'code',
        :redirect_uri => 'http://tst.com/auth',
        :state => 'save-this'
      }
    end

    subject do
      PreAuthorization.new(server, client, attributes)
    end

    it 'is authorizable when request is valid' do
      subject.should be_authorizable
    end

    it 'accepts code as response type' do
      subject.response_type = 'code'
      subject.should be_authorizable
    end

    it 'accepts token as response type' do
      subject.response_type = 'token'
      subject.should be_authorizable
    end

    it 'accepts valid scopes' do
      subject.scope = 'public'
      subject.should be_authorizable
    end

    it 'uses default scopes when none is required' do
      server.stub :default_scopes => Scopes.from_string('default')
      subject.scope = nil
      subject.scope.should  == 'default'
      subject.scopes.should == Scopes.from_string('default')
    end

    it 'accepts test uri' do
      subject.redirect_uri = 'urn:ietf:wg:oauth:2.0:oob'
      subject.should be_authorizable
    end

    it "matches the redirect uri against client's one" do
      subject.redirect_uri = 'http://nothesame.com'
      subject.should_not be_authorizable
    end

    it 'stores the state' do
      subject.state.should == 'save-this'
    end

    it 'rejects if response type is not allowed' do
      subject.response_type = 'whops'
      subject.should_not be_authorizable
    end

    it 'requires an existing client' do
      subject.client = nil
      subject.should_not be_authorizable
    end

    it 'requires a redirect uri' do
      subject.redirect_uri = nil
      subject.should_not be_authorizable
    end

    it 'rejects non-valid scopes' do
      subject.scope = 'invalid'
      subject.should_not be_authorizable
    end
  end
end
