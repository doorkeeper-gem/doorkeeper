# frozen_string_literal: true

module RequestMockHelper
  # Builds a minimal mock rack request for unit testing the client
  # authentication strategies. We don't need a full request spec here, just
  # enough of an +ActionDispatch::Request+ to exercise the matching and
  # authentication logic.
  #
  # Parameters are stringified to mirror what Rack/ActionDispatch actually
  # hand back from +request_parameters+ (string keys), so specs genuinely
  # exercise the strategies' indifferent-access handling instead of silently
  # passing on the symbol keys they were written with.
  def mock_request(request_parameters: {}, query_parameters: {}, authorization: nil, request_method: "POST")
    request = ActionDispatch::Request.new(
      "REQUEST_METHOD" => request_method,
      "SERVER_NAME" => "example.org",
      "SERVER_PORT" => "80",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "rack.url_scheme" => "http",
      "HTTP_HOST" => "example.org",
      # Without PATH_INFO the request's path is "", which makes an endpoint URL
      # built from it indistinguishable from the server's base URL.
      "PATH_INFO" => "/test",
      "ORIGINAL_FULLPATH" => "/test",
      "action_dispatch.remote_ip" => "127.0.0.1",
      "action_dispatch.request.query_parameters" => query_parameters.deep_stringify_keys,
      "action_dispatch.request.request_parameters" => request_parameters.deep_stringify_keys,
    )

    request.env["HTTP_AUTHORIZATION"] = authorization unless authorization.nil?

    request
  end
end

RSpec.configuration.send :include, RequestMockHelper
