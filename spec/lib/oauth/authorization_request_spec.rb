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
        :scope         => "public write",
        :state         => "return-this"
      }
    end

    before :each do
      Doorkeeper.stub_chain(:configuration, :scopes, :exists?).and_return(true)
      Doorkeeper.stub_chain(:configuration, :scopes, :all).and_return([Doorkeeper::Scope.new(:public)])
    end

    describe "with valid attributes" do
      subject { AuthorizationRequest.new(resource_owner, attributes) }

      describe "after authorization" do
        before { subject.authorize }

        its(:response_type) { should == "code" }
        its(:client_id)     { should == client.uid }
        its(:scope)         { should == "public write" }
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

      describe :scopes  do
        it "returns scopes objects returned by Doorkeeper::Scopes with names specified by scopes" do
          scopes_object = double(Doorkeeper::Scopes)
          Doorkeeper.stub_chain(:configuration, :scopes, :with_names).with("public", "write").and_return(scopes_object)
          subject.scopes.should == scopes_object
        end
      end

      describe :authorize do
        let(:authorization_request) { AuthorizationRequest.new(resource_owner, attributes) }
        subject { authorization_request.authorize }

        it "returns AccessGrant object" do
          subject.is_a? AccessGrant
        end

        it "returns instance saved in the database" do
          subject.should be_persisted
        end

        it "returns object thath has scopes attribtue same as scope attribute of authorization request" do
          subject.scopes == authorization_request.scope
        end
      end

    end

    describe "if no scope given" do
      it "sets the scope to the default one" do
        Doorkeeper.stub_chain(:configuration, :default_scope_string).and_return("public email")
        request = AuthorizationRequest.new(resource_owner, attributes.except(:scope))
        request.scope.should == "public email"
      end
    end

    describe "with errors" do
      before do
        AccessGrant.should_not_receive(:create)
        Doorkeeper.stub_chain(:configuration, :scopes, :all).and_return([Doorkeeper::Scope.new(:public)])
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

      describe "when :scope contains scopes that are note registered in the provider" do
        before :each do
          Doorkeeper.stub_chain(:configuration, :scopes, :exists?).and_return(false)
        end

        subject     { auth(attributes.merge(:scope => "public strange")) }
        its(:error) { should == :invalid_scope }
      end

      ["", " ", "\r\n", "\t", "\rsth\n"].each do |invalid_value|
        describe "when :scope has #{invalid_value.inspect}" do
          subject     { auth(attributes.merge(:scope => invalid_value)) }
          its(:error) { should == :invalid_scope }
        end
      end
    end

    def auth(attributes)
      AuthorizationRequest.new(resource_owner, attributes)
    end
  end
end
