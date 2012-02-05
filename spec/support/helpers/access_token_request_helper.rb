module AccessTokenRequestHelper
  def client_is_authorized(client, resource_owner, access_token_attributes = {})
    attributes = {
      :application => client,
      :resource_owner_id => resource_owner.id
    }.merge(access_token_attributes)
    Factory(:access_token, attributes)
  end

  def with_access_token_header(token)
    with_header 'Authorization', "Bearer #{token}"
  end

  def with_header(header, value)
    page.driver.header header, value
  end

  def with_access_token_header(token)
    page.driver.header 'Authorization', "Bearer #{token}"
  end

  def response_status_should_be(status)
    page.driver.response.status.to_i.should == status
  end
end

RSpec.configuration.send :include, AccessTokenRequestHelper, :type => :request
