module AccessTokenRequestHelper
  def client_is_authorized(client, resource_owner, access_token_attributes = {})
    attributes = {
      application: client,
      resource_owner_uid: resource_owner.send(RESOURCE_OWNER_PROPERTY)
    }.merge(access_token_attributes)
    FactoryGirl.create(:access_token, attributes)
  end
end

RSpec.configuration.send :include, AccessTokenRequestHelper, type: :request
