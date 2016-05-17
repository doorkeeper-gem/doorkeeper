# Rails 5 deprecates calling HTTP action methods with positional arguments
# in favor of keyword arguments. However, the keyword argument form is only
# supported in Rails 5+. Since we support back to 4, we need some sort of shim
# to avoid super noisy deprecations when running tests.
module HTTPMethodShim
  def get(path, params = nil, headers = nil)
    super(path, params: params, headers: headers)
  end

  def post(path, params = nil, headers = nil)
    super(path, params: params, headers: headers)
  end

  def put(path, params = nil, headers = nil)
    super(path, params: params, headers: headers)
  end
end

if ::Rails::VERSION::MAJOR >= 5
  RSpec.configure do |config|
    config.include HTTPMethodShim, type: :controller
    config.include HTTPMethodShim, type: :request
  end
end
