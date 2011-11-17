require "spec_helper"

module Doorkeeper::OAuth
  describe AuthorizationRequest do
    describe "issuing an authorization code" do
      let(:client)   { Factory(:application) }
      let(:resource) { double(:resource, :id => 1) }

      subject { create_code_request_for(client, resource) }

      it "creates the authorization grant" do
        subject.authorize
        subject.token.should_not be_nil
      end

      it "appends the code to client's redirect_uri" do
        subject.authorize
        uri = URI.parse(subject.redirect_uri)
        uri.query.should =~ %r{code=\w+}
      end

      its(:client_name)   { should eq(client.name) }
      its(:client_id)     { should eq(client.uid) }
      its(:response_type) { should eq("code") }
    end

    describe "redirecting with error" do
      let(:client)   { Factory(:application) }
      let(:resource) { double(:resource, :id => 1) }

      before do
        AccessGrant.should_not_receive(:create)
      end

      it "redirects with :invalid_request when missing response_type" do
        auth = AuthorizationRequest.new(resource, default_params.except(:response_type))
        auth.authorize
        auth.invalid_redirect_uri.should == "https://app.com/callback?error=invalid_request"
      end

      it "raises an error when redirect_uri is mismatch" do
        auth = AuthorizationRequest.new(resource, default_params.merge(:redirect_uri => "http://mismatch.com"))
        expect {
          auth.authorize
        }.to raise_error(MismatchRedirectURI)
      end
    end

    def create_code_request_for(client, resource)
      AuthorizationRequest.new(resource, default_params)
    end

    def default_params
      {
        :response_type => "code",
        :client_id => client.uid,
        :redirect_uri => client.redirect_uri,
      }
    end
  end
end
