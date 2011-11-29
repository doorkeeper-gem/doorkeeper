module AccessTokenRequestHelper
  def client_is_authorized(client, resource_owner)
    Factory(:access_token, :application => client, :resource_owner_id => resource_owner.id)
  end
end
