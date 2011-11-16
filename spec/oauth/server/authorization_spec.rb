require "spec_helper"

module OAuth::Server

  describe Authorization do

    describe "issuing an authorization code" do
      let(:application) { double(:application, :redirect_uri => "https://application.com/callback") }
      let(:grant)       { double(:grant, :code => "XaByCz") }
      let(:resource)    { double(:resource) }

      describe "with valid application and parameters" do
        before do
          AccessGrant.should_receive(:create)
            .with(:application => application, :resource => resource)
            .and_return(grant)
        end

        it "generates an grant token" do
          grant = Authorization.new(application, resource)
          grant.grant!
          grant.token.should == 'XaByCz'
        end

        it "appends the generated grant in the redirection uri" do
          grant = Authorization.new(application, resource)
          grant.grant!
          grant.redirect_uri.should == "https://application.com/callback?code=XaByCz"
        end
      end

      describe "with invalid redirection uri" do
        before do
          AccessGrant.should_not_receive(:create)
        end

        it "raises an InvalidRedirectionURI exception" do
          grant = Authorization.new(application, resource, :redirect_uri => "invalid")
          expect {
            grant.grant!
          }.to raise_error(Authorization::InvalidRedirectionURI)
        end
      end
    end

  end

end
