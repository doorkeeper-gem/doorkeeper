shared_examples "an accessible token" do
  describe :accessible? do
    it "is accessible if token is not expired" do
      subject.stub :expired? => false
      should be_accessible
    end

    it "is not accessible if token is expired" do
      subject.stub :expired? => true
      should_not be_accessible
    end
  end
end

shared_examples "a revocable token" do
  describe :accessible? do
    before { subject.save! }

    it "is accessible if token is not revoked" do
      subject.should be_accessible
    end

    it "is not accessible if token is revoked" do
      subject.revoke
      subject.should_not be_accessible
    end
  end
end

shared_examples "an unique token" do
  describe :token do
    it "is unique" do
      tokens = []
      3.times do
        token = FactoryGirl.create(factory_name).token
        tokens.should_not include(token)
      end
    end

    it "is generated before validation" do
      expect { subject.valid? }.to change { subject.token }.from(nil)
    end
  end
end
