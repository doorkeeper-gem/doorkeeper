require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe AuthorizationRequest do
    let(:resource_owner) { double(:resource_owner, :id => 1) }
    let(:client)         { FactoryGirl.create(:application) }
    let(:base_attributes) do
      {
        :redirect_uri  => client.redirect_uri,
        :scope         => "public write",
        :state         => "return-this"
      }
    end

    before :each do
      Doorkeeper.stub_chain(:configuration, :confirm_application_owner?).and_return(false)
      Doorkeeper.configuration.stub(:default_scopes).and_return(Doorkeeper::OAuth::Scopes.from_string('public write'))
    end

    describe "with a code response_type" do
      let(:attributes) { base_attributes.merge!(:response_type => "code") }

      describe "with valid attributes" do
        subject { AuthorizationRequest.new(client, resource_owner, attributes) }

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

        describe :authorize do
          let(:authorization_request) { AuthorizationRequest.new(client, resource_owner, attributes) }
          subject { authorization_request.authorize }

          it "returns Doorkeeper::AccessGrant object" do
            subject.is_a? Doorkeeper::AccessGrant
          end

          it "returns instance saved in the database" do
            subject.should be_persisted
          end

          it "returns object that has scopes attribute same as scope attribute of authorization request" do
            subject.scopes == authorization_request.scope
          end
        end
      end

      describe "with a redirect_uri with query params" do
        let(:original_query_params) { "abc=123&def=456" }
        let(:attributes_with_query_params) {
          u = URI.parse(client.redirect_uri)
          u.query = original_query_params
          attributes[:redirect_uri] = u.to_s
          attributes
        }
        subject { AuthorizationRequest.new(client, resource_owner, attributes_with_query_params) }

        it "preservers the original query when error"

        describe "after authorization" do
          before { subject.authorize }

          describe ".success_redirect_uri" do
            let(:query) { URI.parse(subject.success_redirect_uri).query }

            it "includes the grant code" do
              query.should =~ %r{code=\w+}
            end

            it "includes the state previous assumed" do
              query.should =~ %r{state=return-this}
            end

            it "preserves the original query parameters" do
              query.should =~ /abc=123/
              query.should =~ /def=456/
            end
          end
        end
      end

      describe "if no scope given" do
        it "sets the scope to the default one" do
          request = AuthorizationRequest.new(client, resource_owner, attributes.except(:scope))
          request.scopes.to_s.should == "public write"
        end
      end

      describe "with errors" do
        before do
          Doorkeeper::AccessGrant.should_not_receive(:create)
        end

        describe "when :response_type is missing" do
          subject     { auth(attributes.except(:response_type)) }
          its(:error) { should == :invalid_request }
        end

        describe "when :redirect_uri is missing" do
          subject     { auth(attributes.except(:redirect_uri)) }
          its(:error) { should == :invalid_redirect_uri }
        end

        describe "when client is not present" do
          subject     { AuthorizationRequest.new(nil, resource_owner, attributes) }
          its(:error) { should == :invalid_client }
        end

        describe "when :redirect_uri mismatches" do
          subject     { auth(attributes.merge(:redirect_uri => "http://example.com/mismatch")) }
          its(:error) { should == :invalid_redirect_uri }
        end

        describe "when :redirect_uri contains a fragment" do
          subject     { auth(attributes.merge(:redirect_uri => (client.redirect_uri + "#abc"))) }
          its(:error) { should == :invalid_redirect_uri }
        end

        describe "when :redirect_uri is not a valid URI" do
          subject     { auth(attributes.merge(:redirect_uri => "invalid")) }
          its(:error) { should == :invalid_redirect_uri }
        end

        describe "when :response_type is not 'code' or 'token'" do
          subject     { auth(attributes.merge(:response_type => "invalid")) }
          its(:error) { should == :unsupported_response_type }
        end

        describe "when :scope contains scopes that are note registered in the provider" do
          subject     { auth(attributes.merge(:scope => "public strange")) }
          its(:error) { should == :invalid_scope }
        end
      end
    end

    describe "with a token response_type" do
      before do
        Doorkeeper.configuration.stub(:access_token_expires_in).and_return(7200)
      end

      let(:attributes) { base_attributes.merge!(:response_type => "token") }

      describe "with valid attributes" do
        subject { AuthorizationRequest.new(client, resource_owner, attributes) }

        describe "after authorization" do
          before { subject.authorize }

          its(:response_type) { should == "token" }
          its(:scope)         { should == "public write" }
          its(:state)         { should == "return-this" }
          its(:error)         { should be_nil }

          describe ".success_redirect_uri" do
            let(:fragment) { URI.parse(subject.success_redirect_uri).fragment }

            it "has a fragment" do
              fragment.should_not be_nil
            end

            it "doesn't have query parameters" do
              URI.parse(subject.success_redirect_uri).query.should be_nil
            end

            it "includes the access token" do
              fragment.should =~ %r{access_token=\w+}
            end

            it "includes the token type" do
              fragment.should =~ %r{token_type=bearer}
            end

            it "includes the expires in" do
              fragment.should =~ %r{expires_in=\w+}
            end

            it "includes the state previous assumed" do
              fragment.should =~ %r{state=return-this}
            end
          end
        end

        describe :authorize do
          let(:authorization_request) { AuthorizationRequest.new(client, resource_owner, attributes) }
          subject { authorization_request.authorize }

          it "returns Doorkeeper::AccessGrant object" do
            subject.is_a? Doorkeeper::AccessGrant
          end

          it "returns instance saved in the database" do
            subject.should be_persisted
          end

          it "returns object that has scopes attribute same as scope attribute of authorization request" do
            subject.scopes == authorization_request.scope
          end
        end
      end

      describe "if no scope given" do
        it "sets the scope to the default one" do
          request = AuthorizationRequest.new(client, resource_owner, attributes.except(:scope))
          request.scopes.to_s.should == "public write"
        end
      end

      describe "with errors" do
        before do
          Doorkeeper::AccessGrant.should_not_receive(:create)
        end

        describe "when :response_type is missing" do
          subject     { auth(attributes.except(:response_type)) }
          its(:error) { should == :invalid_request }
        end

        describe "when :redirect_uri is missing" do
          subject     { auth(attributes.except(:redirect_uri)) }
          its(:error) { should == :invalid_redirect_uri }
        end

        describe "when client is not present" do
          subject     { AuthorizationRequest.new(nil, resource_owner, attributes) }
          its(:error) { should == :invalid_client }
        end

        describe "when :redirect_uri has a fragment" do
          subject { auth(attributes.merge(:redirect_uri => client.redirect_uri + "#xyz")) }
          its(:error) { should == :invalid_redirect_uri }
        end

        describe "when :redirect_uri is a relative URI" do
          subject { auth(attributes.merge(:redirect_uri => "/abcdef")) }
          its(:error) { should == :invalid_redirect_uri }
        end

        describe "when :redirect_uri mismatches" do
          subject     { auth(attributes.merge(:redirect_uri => "http://example.com/mismatch")) }
          its(:error) { should == :invalid_redirect_uri }
        end

        describe "when :redirect_uri contains a fragment" do
          subject     { auth(attributes.merge(:redirect_uri => (client.redirect_uri + "#abc"))) }
          its(:error) { should == :invalid_redirect_uri }
        end

        describe "when :redirect_uri is not a valid URI" do
          subject     { auth(attributes.merge(:redirect_uri => "invalid")) }
          its(:error) { should == :invalid_redirect_uri }
        end

        describe "when :response_type is not 'code' or 'token'" do
          subject     { auth(attributes.merge(:response_type => "invalid")) }
          its(:error) { should == :unsupported_response_type }
        end

        describe "when :scope contains scopes that are note registered in the provider" do
          subject     { auth(attributes.merge(:scope => "public strange")) }
          its(:error) { should == :invalid_scope }
        end
      end
    end

    def auth(attributes)
      AuthorizationRequest.new(client, resource_owner, attributes)
    end
  end
end
