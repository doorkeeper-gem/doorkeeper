require "spec_helper"

module Doorkeeper::OAuth
  describe AuthorizationRequest, "with valid attributes" do
    let(:resource_owner) { double(:resource_owner, :id => 1) }
    let(:client)         { Factory(:application) }
    let(:attributes) do
      {
        :response_type => "code",
        :client_id     => client.uid,
        :redirect_uri  => client.redirect_uri,
        :scope         => "public",
        :state         => "return-this"
      }
    end

    subject { AuthorizationRequest.new(resource_owner, attributes) }

    before { subject.authorize }

    its(:response_type) { should == "code" }
    its(:client_id)     { should == client.uid }
    its(:scope)         { should == "public" }
    its(:state)         { should == "return-this" }
    its(:error)         { should be_nil }

    describe ".success_redirect_uri" do
      let(:query) { URI.parse(subject.success_redirect_uri).query }

      it "includes the grant code" do
        query.should =~ %r{code=\w+}
      end

      it "includes the state previous assumed" do
        query.should =~ %r{state=return-this}
      end
    end
  end

  describe AuthorizationRequest, "with errors" do
    let(:resource_owner) { double(:resource_owner, :id => 1) }
    let(:client)         { Factory(:application) }
    let(:attributes) do
      {
        :response_type => "code",
        :client_id     => client.uid,
        :redirect_uri  => client.redirect_uri,
        :scope         => "public",
        :state         => "return-this"
      }
    end

    before do
      AccessGrant.should_not_receive(:create)
    end

    describe ":invalid_request" do
      [:response_type, :client_id, :redirect_uri].each do |attribute|
        it "when :#{attribute} is missing" do
          auth = build_auth(resource_owner, attributes.except(attribute))
          auth.should_not be_valid
          auth.error.should == :invalid_request
        end
      end
    end

    describe ":invalid_client" do
      it "when :client_id does not match" do
        auth = build_auth(resource_owner, attributes.merge(:client_id => "invalid"))
        auth.should_not be_valid
        auth.error.should == :invalid_client
      end
    end

    describe ":invalid_redirect_uri" do
      it "when :redirect_uri mismatches" do
        auth = build_auth(resource_owner, attributes.merge(:redirect_uri => "mismatch"))
        auth.should_not be_valid
        auth.error.should == :invalid_redirect_uri
      end
    end

    describe ":unsupported_response_type" do
      it "when :response_type is not 'code'" do
        auth = build_auth(resource_owner, attributes.merge(:response_type => "invalid"))
        auth.should_not be_valid
        auth.error.should == :unsupported_response_type
      end
    end

    def build_auth(resource, attributes)
      AuthorizationRequest.new(resource_owner, attributes)
    end
  end
end
