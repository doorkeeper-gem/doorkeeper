require 'spec_helper_integration'

describe 'Custom controller for routes' do
  it 'GET /space/oauth/authorize routes to custom authorizations controller' do
    get('/space/oauth/authorize').should route_to('custom_authorizations#new')
  end

  it 'POST /space/oauth/authorize routes to custom authorizations controller' do
    post('/space/oauth/authorize').should route_to('custom_authorizations#create')
  end

  it 'DELETE /space/oauth/authorize routes to custom authorizations controller' do
    delete('/space/oauth/authorize').should route_to('custom_authorizations#destroy')
  end
end
