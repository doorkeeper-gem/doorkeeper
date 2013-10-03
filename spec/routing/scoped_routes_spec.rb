require 'spec_helper_integration'

describe 'Scoped routes' do
  it 'GET /scope/authorize routes to authorizations controller' do
    get('/scope/authorize').should route_to('doorkeeper/authorizations#new')
  end

  it 'POST /scope/authorize routes to authorizations controller' do
    post('/scope/authorize').should route_to('doorkeeper/authorizations#create')
  end

  it 'DELETE /scope/authorize routes to authorizations controller' do
    delete('/scope/authorize').should route_to('doorkeeper/authorizations#destroy')
  end

  it 'POST /scope/token routes to tokens controller' do
    post('/scope/token').should route_to('doorkeeper/tokens#create')
  end

  it 'GET /scope/applications routes to applications controller' do
    get('/scope/applications').should route_to('doorkeeper/applications#index')
  end

  it 'GET /scope/authorized_applications routes to authorized applications controller' do
    get('/scope/authorized_applications').should route_to('doorkeeper/authorized_applications#index')
  end

  it 'GET /scope/token/info route to authorzed tokeninfo controller' do
    get('/scope/token/info').should route_to('doorkeeper/token_info#show')
  end

end
