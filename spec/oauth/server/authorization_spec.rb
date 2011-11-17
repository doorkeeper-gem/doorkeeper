require "spec_helper"

module OAuth::Server

  describe Authorization do

    describe "issuing an authorization code" do
      let(:client)   { double(:client, :redirect_uri => "https://client.com/callback") }
      let(:grant)    { double(:grant, :code => "XaByCz") }
      let(:resource) { double(:resource) }

      describe "with valid client and parameters" do
        before do
          AccessGrant.should_receive(:create)
            .with(:client => client, :resource => resource)
            .and_return(grant)
        end

        it "generates an grant token" do
          grant = Authorization.new(client, resource)
          grant.grant!
          grant.token.should == 'XaByCz'
        end

        it "appends the generated grant in the redirection uri" do
          grant = Authorization.new(client, resource)
          grant.grant!
          grant.redirect_uri.should == "https://client.com/callback?code=XaByCz"
        end
      end

      describe "with invalid redirection uri" do
        before do
          AccessGrant.should_not_receive(:create)
        end

        it "raises an InvalidRedirectionURI exception" do
          grant = Authorization.new(client, resource, :redirect_uri => "invalid")
          expect {
            grant.grant!
          }.to raise_error(Authorization::InvalidRedirectionURI)
        end
      end
    end

  end

end
