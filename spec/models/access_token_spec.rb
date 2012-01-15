require 'spec_helper_integration'

describe AccessToken do
  subject { Factory.build(:access_token) }

  it { should be_valid }

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

  describe "token" do
    it "is unique" do
      tokens = []
      3.times do
        token = Factory(:access_token).token
        tokens.should_not include(token)
      end
    end

    it "is generated before validation" do
      expect { subject.valid? }.to change { subject.token }.from(nil)
    end
  end

  describe "revoke" do
    subject { Factory(:access_token) }

    it "updates the revoked attribute" do
      expect {
        subject.revoke
      }.to change { subject.revoked? }.from(false).to(true)
    end

    it "is not accessible" do
      subject.revoke
      subject.should_not be_accessible
    end
  end

  describe "token expiration" do
    subject { Factory(:access_token, :expires_in => 2.hours) }

    context "when expiration time has not passed" do
      it { should_not be_expired }
      it { should     be_accessible }
    end

    context "when expiration time is over" do
      around do |example|
        subject # force creation
        Timecop.freeze(Time.now + 3.hours) { example.call }
      end

      it { should     be_expired }
      it { should_not be_accessible }
    end
  end

  describe ".has_authorized_token_for?" do
    let(:resource_owner) { stub(:id => 1) }
    let(:application)    { Factory :application }
    let(:scopes)         { "public write" }
    let(:default_attributes) do
      { :application => application, :resource_owner_id => resource_owner.id, :scopes => scopes }
    end

    it "is authorized if application, resource owner and scopes matches" do
      Factory :access_token, default_attributes
      token = AccessToken.has_authorized_token_for?(application, resource_owner, scopes)
      token.should be_true
    end

    it "is not authorized if application does not match" do
      Factory :access_token, default_attributes.merge(:application => Factory(:application))
      token = AccessToken.has_authorized_token_for?(application, resource_owner, scopes)
      token.should be_false
    end

    it "is not authorized if resource_owner does not match" do
      Factory :access_token, default_attributes.merge(:resource_owner_id => 2)
      token = AccessToken.has_authorized_token_for?(application, resource_owner, scopes)
      token.should be_false
    end

    it "is not authorized if token was revoked" do
      Factory :access_token, default_attributes.merge(:revoked_at => 1.hour.ago)
      token = AccessToken.has_authorized_token_for?(application, resource_owner, scopes)
      token.should be_false
    end

    it "is not authorized if scopes differs" do
      Factory :access_token, default_attributes.merge(:scopes => "public email")
      token = AccessToken.has_authorized_token_for?(application, resource_owner, scopes)
      token.should be_false
    end

    it "validates scopes against the most recent token" do
      Factory :access_token, default_attributes.merge(:created_at => 2.days.ago, :scopes => "another scope")
      Factory :access_token, default_attributes
      token = AccessToken.has_authorized_token_for?(application, resource_owner, scopes)
      token.should be_true
    end
  end
end
