shared_context "valid token" do
  let :token_string do
    "1A2B3C4D"
  end

  let :token do
    double(AccessToken, :accessible? => true)
  end

  before :each do
    AccessToken.should_receive(:find_by_token).with(token_string).and_return(token)
  end
end

shared_context "invalid token" do
  let :token_string do
    "1A2B3C4D"
  end

  let :token do
    double(AccessToken, :accessible? => false)
  end

  before :each do
    AccessToken.should_receive(:find_by_token).with(token_string).and_return(token)
  end
end

shared_context "authenticated resource owner" do
  before do
    controller.stub(:current_resource_owner) { double(:resource, :id => 1) }
  end
end

shared_context "valid authorization request" do
  let :authorization do
    double(:authorization, :valid? => true, :authorize => true, :success_redirect_uri => "http://something.com/cb?code=token")
  end

  before do
    controller.stub(:authorization) { authorization }
  end
end

shared_context "invalid authorization request" do
  let :authorization do
    double(:authorization, :valid? => false, :authorize => false)
  end

  before do
    controller.stub(:authorization) { authorization }
  end
end
