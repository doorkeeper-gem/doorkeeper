require 'spec_helper'

describe AccessGrant do
  subject { Factory.build(:access_grant) }

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

    it "is invalid without token" do
      subject.save
      subject.token = nil
      should_not be_valid
    end

    it "is invalid without expires_in" do
      subject.expires_in = nil
      should_not be_valid
    end
  end

  describe "token" do
    it "is unique" do
      tokens = []
      3.times do
        token = Factory(:access_grant).token
        tokens.should_not include(token)
      end
    end

    it "is generated before validation" do
      expect { subject.valid? }.to change { subject.token }.from(nil)
    end
  end

  describe "expired?" do
    it "is not expired when" do
      grant = Factory(:access_grant, :expires_in => 1000)
      grant.should_not be_expired
      grant.should be_accessible
    end

    it "is true if expired" do
      grant = Factory(:access_grant, :expires_in => 400)
      Timecop.freeze(Time.now + 600.seconds) do
        grant.should be_expired
        grant.should_not be_accessible
      end
    end
  end

  describe "revoke token" do
    before { subject.save! }

    describe "for new grants" do
      it { should_not be_revoked }
      it { should     be_accessible }
    end

    describe "when is revoked" do
      before { subject.revoke }
      it { should     be_revoked }
      it { should_not be_accessible }
    end
  end
end
