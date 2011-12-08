module AccessTokenRequestHelper
  def client_is_authorized(client, resource_owner)
    Factory(:access_token, :application => client, :resource_owner_id => resource_owner.id)
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

  def parsed_response
    JSON.parse(response.body)
  end
end

RSpec.configuration.send :include, AccessTokenRequestHelper, :type => :request
