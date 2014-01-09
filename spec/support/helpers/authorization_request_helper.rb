module AuthorizationRequestHelper
  def resource_owner_is_authenticated(resource_owner = nil)
    resource_owner ||= User.create!(:name => "Joe", :password => "sekret")
    Doorkeeper.configuration.instance_variable_set(:@authenticate_resource_owner, proc { resource_owner })
  end

  def resource_owner_is_not_authenticated
    Doorkeeper.configuration.instance_variable_set(:@authenticate_resource_owner, proc { redirect_to("/sign_in") })
  end

  def default_scopes_exist(*scopes)
    Doorkeeper.configuration.instance_variable_set(:@default_scopes, Doorkeeper::OAuth::Scopes.from_array(scopes))
  end

  def optional_scopes_exist(*scopes)
    Doorkeeper.configuration.instance_variable_set(:@optional_scopes, Doorkeeper::OAuth::Scopes.from_array(scopes))
  end

  def client_should_be_authorized(client)
    client.should have(1).access_grants
  end

  def client_should_not_be_authorized(client)
    client.should have(0).access_grants
  end

  def i_should_be_on_client_callback(client)
    client.redirect_uri.should == "#{current_uri.scheme}://#{current_uri.host}#{current_uri.path}"
  end
end

RSpec.configuration.send :include, AuthorizationRequestHelper, :type => :request
