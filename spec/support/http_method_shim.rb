# Rails 5 deprecates calling HTTP action methods with positional arguments
# in favor of keyword arguments. However, the keyword argument form is only
# supported in Rails 5+. Since we support back to 4, we need some sort of shim
# to avoid super noisy deprecations when running tests.
module RoutingHTTPMethodShim
  def get(path, **args)
    super(path, args[:params], args[:headers])
  end

  def post(path, **args)
    super(path, args[:params], args[:headers])
  end

  def put(path, **args)
    super(path, args[:params], args[:headers])
  end
end

module ControllerHTTPMethodShim
  def process(action, http_method = 'GET', **args)
    if (as = args.delete(:as))
      @request.headers['Content-Type'] = Mime[as].to_s
    end

    super(action, http_method, args[:params], args[:session], args[:flash])
  end
end

if ::Rails::VERSION::MAJOR < 5
  RSpec.configure do |config|
    config.include ControllerHTTPMethodShim, type: :controller
    config.include RoutingHTTPMethodShim, type: :request
  end
end
