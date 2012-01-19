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
