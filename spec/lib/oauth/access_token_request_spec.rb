require "spec_helper"

describe Doorkeeper::OAuth::AccessTokenRequest do
  include Doorkeeper::OAuth

  let(:client) { Factory(:application) }
  let(:grant)  { Factory(:access_grant, :application => client) }
  let(:params) {
    {
      :client_id     => client.uid,
      :client_secret => client.secret,
      :code          => grant.token,
      :grant_type    => "authorization_code",
      :redirect_uri  => client.redirect_uri
    }
  }

  describe "with a valid authorization code and client" do
    subject { AccessTokenRequest.new(params) }

    before { subject.authorize }

    it { should be_valid }
    its(:access_token) { should =~ /\w+/ }
    its(:token_type)   { should == "bearer" }
    its(:error)        { should be_nil }
  end

  describe "with errors" do
    def token(params)
      AccessTokenRequest.new(params)
    end

    it "includes the error in the response" do
      access_token = token(params.except(:grant_type))
      access_token.error_response['error'].should == "invalid_request"
    end

    [:grant_type, :code, :redirect_uri].each do |param|
      describe "when :#{param} is missing" do
        subject     { token(params.except(param)) }
        its(:error) { should == :invalid_request }
      end
    end

    describe "when :client_id does not match" do
      subject     { token(params.merge(:client_id => "inexistent")) }
      its(:error) { should == :invalid_client }
    end

    describe "when :client_secret does not match" do
      subject     { token(params.merge(:client_secret => "inexistent")) }
      its(:error) { should == :invalid_client }
    end

    describe "when :code does not exist" do
      subject     { token(params.merge(:code => "inexistent")) }
      its(:error) { should == :invalid_grant }
    end

    describe "when :redirect_uri does not match with grant's one" do
      subject     { token(params.merge(:redirect_uri => "another")) }
      its(:error) { should == :invalid_grant }
    end

    describe "when :grant_type is not 'authorization_code'" do
      subject     { token(params.merge(:grant_type => "invalid")) }
      its(:error) { should == :unsupported_grant_type }
    end

    describe "when granted application does not match" do
      subject { token(params) }

      before do
        grant.application = Factory(:application)
        grant.save!
      end

      its(:error) { should == :invalid_grant }
    end

    describe "when :code is expired" do
      it "error is :invalid_grant" do
        grant # create grant instance
        Timecop.freeze(Time.now + 700.seconds) do
          expired = token(params)
          expired.error.should == :invalid_grant
        end
      end
    end
  end
end
