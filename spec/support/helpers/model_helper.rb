module ModelHelper
  def client_exists(client_attributes = {})
    @client = FactoryGirl.create(:application, client_attributes)
  end

  def create_resource_owner
    @resource_owner = User.create!(:name => "Joe", :password => "sekret")
  end

  def authorization_code_exists(options = {})
    @authorization = FactoryGirl.create(:access_grant, options)
  end

  def access_grant_should_exist_for(client, resource_owner)
    grant = Doorkeeper::AccessGrant.first
    grant.application.should == client
    grant.resource_owner_id  == resource_owner.id
  end

  def access_token_should_exist_for(client, resource_owner)
    grant = Doorkeeper::AccessToken.first
    grant.application.should == client
    grant.resource_owner_id  == resource_owner.id
  end

  def access_grant_should_not_exist
    Doorkeeper::AccessGrant.all.should be_empty
  end

  def access_token_should_not_exist
    Doorkeeper::AccessToken.all.should be_empty
  end

  def access_grant_should_have_scopes(*args)
    grant = Doorkeeper::AccessGrant.first
    grant.scopes.should == Doorkeeper::OAuth::Scopes.from_array(args)
  end

  def access_token_should_have_scopes(*args)
    grant = Doorkeeper::AccessToken.first
    grant.scopes.should == Doorkeeper::OAuth::Scopes.from_array(args)
  end
end

RSpec.configuration.send :include, ModelHelper, :type => :request
