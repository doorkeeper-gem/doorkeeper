require 'spec_helper_integration'

describe AccessGrant do
  subject { Factory.build(:access_grant) }

  it { should be_valid }

  it_behaves_like "an accessible token"

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

  describe :scopes, "returns an array of scopes" do
    subject { Factory(:access_grant, :scopes => "public write").scopes }

    it { should be_kind_of(Array) }
    its(:count) { should == 2 }
    it { should include(:public, :write) }
  end
end
