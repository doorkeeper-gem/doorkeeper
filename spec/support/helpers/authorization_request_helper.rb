module AuthorizationRequestHelper
  def resource_owner_is_authenticated(resource_owner = nil)
    resource_owner ||= User.create!
    Doorkeeper.configuration.stub(:authenticate_resource_owner => proc { resource_owner })
  end

  def client_exists(client_attributes = {})
    @client = Factory(:application, client_attributes)
  end

  def authorization_code_exists(options)
    @authorization = Factory(:access_grant, :application => options[:client])
  end

  def authorization_endpoint_url(options = {})
    client_id     = options[:client_id]    ? options[:client_id]    : options[:client].uid
    redirect_uri  = options[:redirect_uri] ? options[:redirect_uri] : options[:client].redirect_uri
    response_type = options[:response_type] || "code"
    "/oauth/authorize?client_id=#{client_id}&redirect_uri=#{redirect_uri}&response_type=#{response_type}"
  end

  def redirect_uri_with_code(uri, code)
    uri = URI.parse(uri)
    uri.query = "code=#{code}"
    uri.to_s
  end

  def redirect_uri_with_error(uri, error)
    uri = URI.parse(uri)
    uri.query = "error=#{error}"
    uri.to_s
  end
end
