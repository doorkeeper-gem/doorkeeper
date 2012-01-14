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
end
