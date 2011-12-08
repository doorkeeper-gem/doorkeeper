module AuthorizationRequestHelper
  def resource_owner_is_authenticated(resource_owner = nil)
    resource_owner = User.create! unless resource_owner
    Doorkeeper.configuration.builder.resource_owner_authenticator do
      resource_owner || redirect_to("/sign_in")
    end
  end

  def client_exists(client_attributes = {})
    @client = Factory(:application, client_attributes)
  end

  def scopes_exist
    Doorkeeper.configuration.builder.authorization_scopes do
      scope :public, :default => true,  :description => "Access your public data"
      scope :write,  :default => false, :description => "Update your data"
    end
  end

  def client_should_be_authorized(client)
    client.should have(1).access_grants
  end

  def client_should_not_be_authorized(client)
    client.should have(0).access_grants
  end

  def authorization_code_exists(options)
    @authorization = Factory(:access_grant, :application => options[:client], :scopes => options[:scopes])
  end

  def i_should_be_on_client_callback(client)
    client.redirect_uri.should == "#{current_uri.scheme}://#{current_uri.host}#{current_uri.path}"
  end
end

RSpec.configuration.send :include, AuthorizationRequestHelper, :type => :request
