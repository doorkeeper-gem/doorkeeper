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
