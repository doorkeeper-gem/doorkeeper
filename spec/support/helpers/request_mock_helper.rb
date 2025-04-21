module RequestMockHelper
  # I'm not sure if there's a better way to get a mock rack request for
  # testing. Here we don't need a full request spec, but we do need enough to
  # check that the logic of these classes works.
  def mock_request(request_parameters: {}, query_parameters: {}, authorization: nil)
    request = ActionDispatch::Request.new({
      "REQUEST_METHOD"=>"POST",
      "SERVER_NAME"=>"example.org",
      "SERVER_PORT"=>"80",
      "SERVER_PROTOCOL"=>"HTTP/1.1",
      "rack.url_scheme"=>"http",
      "HTTP_HOST"=> "example.org",
      "ORIGINAL_FULLPATH" => "/test",
      "action_dispatch.remote_ip" => "127.0.0.1",
      "action_dispatch.request.query_parameters" => query_parameters,
      "action_dispatch.request.request_parameters" => request_parameters
    })

    unless authorization.nil?
      request.env["HTTP_AUTHORIZATION"] = authorization
    end

    request
  end
end

RSpec.configuration.send :include, RequestMockHelper
