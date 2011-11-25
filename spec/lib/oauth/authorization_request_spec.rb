require "spec_helper"

module Doorkeeper::OAuth
  describe AuthorizationRequest do
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

    describe "with valid attributes" do
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

    describe "with errors" do
      before do
        AccessGrant.should_not_receive(:create)
      end

      [:response_type, :client_id, :redirect_uri].each do |attribute|
        describe "when :#{attribute} is missing" do
          subject     { auth(attributes.except(attribute)) }
          its(:error) { should == :invalid_request }
        end
      end

      describe "when :client_id does not match" do
        subject     { auth(attributes.merge(:client_id => "invalid")) }
        its(:error) { should == :invalid_client }
      end

      describe "when :redirect_uri mismatches" do
        subject     { auth(attributes.merge(:redirect_uri => "mismatch")) }
        its(:error) { should == :invalid_redirect_uri }
      end

      describe "when :response_type is not 'code'" do
        subject     { auth(attributes.merge(:response_type => "invalid")) }
        its(:error) { should == :unsupported_response_type }
      end

    end

    def auth(attributes)
      AuthorizationRequest.new(resource_owner, attributes)
    end
  end
end
