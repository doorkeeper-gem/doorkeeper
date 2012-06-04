shared_context "valid token", :token => :valid do
  let :token_string do
    "1A2B3C4D"
  end

  let :token do
    double(Doorkeeper::AccessToken, :accessible? => true)
  end

  before :each do
    Doorkeeper::AccessToken.stub(:authenticate).with(token_string).and_return(token)
  end
end

shared_context "invalid token", :token => :invalid do
  let :token_string do
    "1A2B3C4D"
  end

  let :token do
    double(Doorkeeper::AccessToken, :accessible? => false)
  end

  before :each do
    Doorkeeper::AccessToken.stub(:authenticate).with(token_string).and_return(token)
  end
end

shared_context "authenticated resource owner" do
  before do
    user = double(:resource, :id => 1)
    Doorkeeper.configuration.stub(:authenticate_resource_owner) { proc do user end }
  end
end

shared_context "not authenticated resource owner" do
  before do
    Doorkeeper.configuration.stub(:authenticate_resource_owner) { proc do redirect_to '/' end }
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
    double(:authorization, :valid? => false, :authorize => false, :redirect_on_error? => false)
  end

  before do
    controller.stub(:authorization) { authorization }
  end
end
