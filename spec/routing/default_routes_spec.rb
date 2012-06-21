require 'spec_helper_integration'

describe 'Default routes' do
  it 'GET /oauth/authorize routes to authorizations controller' do
    get('/oauth/authorize').should route_to('doorkeeper/authorizations#new')
  end

  it 'POST /oauth/authorize routes to authorizations controller' do
    post('/oauth/authorize').should route_to('doorkeeper/authorizations#create')
  end

  it 'DELETE /oauth/authorize routes to authorizations controller' do
    delete('/oauth/authorize').should route_to('doorkeeper/authorizations#destroy')
  end

  it 'POST /oauth/token routes to tokens controller' do
    post('/oauth/token').should route_to('doorkeeper/tokens#create')
  end

  it "GET /oauth/tokeninfo routes to tokens controller" do
    get('/oauth/tokeninfo').should route_to('doorkeeper/tokens#tokeninfo')
  end

  it 'GET /oauth/applications routes to applications controller' do
    get('/oauth/applications').should route_to('doorkeeper/applications#index')
  end

  it 'GET /oauth/authorized_applications routes to authorized applications controller' do
    get('/oauth/authorized_applications').should route_to('doorkeeper/authorized_applications#index')
  end
end
