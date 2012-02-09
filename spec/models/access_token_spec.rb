require 'spec_helper_integration'

describe AccessToken do
  subject { Factory.build(:access_token) }

  it { should be_valid }

  it_behaves_like "an accessible token"
  it_behaves_like "a revocable token"
  it_behaves_like "an unique token" do
    let(:factory_name) { :access_token }
  end

  describe "validations" do
    it "is invalid without resource_owner_id" do
      subject.resource_owner_id = nil
      should_not be_valid
    end

    it "is invalid without application_id" do
      subject.application_id = nil
      should_not be_valid
    end
  end

  describe '.revoke_all_for' do
    let(:resource_owner) { stub(:id => 100) }
    let(:application)    { Factory :application }
    let(:default_attributes) do
      { :application => application, :resource_owner_id => resource_owner.id }
    end

    it 'revokes all tokens for given application and resource owner' do
      Factory :access_token, default_attributes
      AccessToken.revoke_all_for application.id, resource_owner
      AccessToken.all.should be_empty
    end

    it 'matches application' do
      Factory :access_token, default_attributes.merge(:application => Factory(:application))
      AccessToken.revoke_all_for application.id, resource_owner
      AccessToken.all.should_not be_empty
    end

    it 'matches resource owner' do
      Factory :access_token, default_attributes.merge(:resource_owner_id => 90)
      AccessToken.revoke_all_for application.id, resource_owner
      AccessToken.all.should_not be_empty
    end
  end

  describe '.matching_token_for' do
    let(:resource_owner_id) { 100 }
    let(:application)       { Factory :application }
    let(:scopes)            { "public write" }
    let(:default_attributes) do
      { :application => application, :resource_owner_id => resource_owner_id, :scopes => scopes }
    end

    it 'returns only one token' do
      token = Factory :access_token, default_attributes
      last_token = AccessToken.matching_token_for(application, resource_owner_id, scopes)
      last_token.should == token
    end

    it 'accepts resource owner as object' do
      resource_owner = stub(:kind_of? => true, :id => 100)
      token = Factory :access_token, default_attributes
      last_token = AccessToken.matching_token_for(application, resource_owner, scopes)
      last_token.should == token
    end

    it 'excludes revoked tokens' do
      Factory :access_token, default_attributes.merge(:revoked_at => 1.day.ago)
      last_token = AccessToken.matching_token_for(application, resource_owner_id, scopes)
      last_token.should be_nil
    end

    it 'matches the application' do
      token = Factory :access_token, default_attributes.merge(:application => Factory(:application))
      last_token = AccessToken.matching_token_for(application, resource_owner_id, scopes)
      last_token.should be_nil
    end

    it 'matches the resource owner' do
      Factory :access_token, default_attributes.merge(:resource_owner_id => 2)
      last_token = AccessToken.matching_token_for(application, resource_owner_id, scopes)
      last_token.should be_nil
    end

    it 'matches the scopes' do
      Factory :access_token, default_attributes.merge(:scopes => 'public email')
      last_token = AccessToken.matching_token_for(application, resource_owner_id, scopes)
      last_token.should be_nil
    end

    it 'returns the last created token' do
      Factory :access_token, default_attributes.merge(:created_at => 1.day.ago)
      token = Factory :access_token, default_attributes
      last_token = AccessToken.matching_token_for(application, resource_owner_id, scopes)
      last_token.should == token
    end
  end
end
