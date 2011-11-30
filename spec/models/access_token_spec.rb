require 'spec_helper'

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

  describe "expired?" do
    let(:expiration) { DateTime.now + 2.days }
    subject { Factory(:access_token, :expires_at => expiration) }

    before { subject }

    it "is false when is not expired" do
      subject.should_not be_expired
    end

    it "is true when is expired" do
      Timecop.freeze(Date.today + 3.days) do
        subject.should be_expired
      end
    end

    it "is not accessible when expired" do
      Timecop.freeze(Date.today + 3.days) do
        subject.should_not be_accessible
      end
    end
  end
end
