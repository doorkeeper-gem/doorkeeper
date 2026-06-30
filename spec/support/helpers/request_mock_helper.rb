# frozen_string_literal: true

module RequestMockHelper
  # Builds a minimal mock rack request for unit testing the client
  # authentication strategies. We don't need a full request spec here, just
  # enough of an +ActionDispatch::Request+ to exercise the matching and
  # authentication logic.
  def mock_request(request_parameters: {}, query_parameters: {}, authorization: nil, request_method: "POST")
    request = ActionDispatch::Request.new(
      "REQUEST_METHOD" => request_method,
      "SERVER_NAME" => "example.org",
      "SERVER_PORT" => "80",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "rack.url_scheme" => "http",
      "HTTP_HOST" => "example.org",
      "ORIGINAL_FULLPATH" => "/test",
      "action_dispatch.remote_ip" => "127.0.0.1",
      "action_dispatch.request.query_parameters" => query_parameters,
      "action_dispatch.request.request_parameters" => request_parameters,
    )

    request.env["HTTP_AUTHORIZATION"] = authorization unless authorization.nil?

    request
  end
end

RSpec.configuration.send :include, RequestMockHelper
