# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientAuthentication::None do
  describe 'matches_request?' do
    it "matches if the request doesn't have authorization or client_secret" do
      request = mock_request({
        client_id: '1234'
      })

      expect(described_class.matches_request?(request)).to be true
    end

    it "doesn't match if the request has client_secret" do
      request = mock_request({
        client_id: '1234',
        client_secret: "5678"
      })

      expect(described_class.matches_request?(request)).to_not be true
    end

    it "doesn't match if the request has authorization" do
      request = mock_request({
        client_id: '1234'
      }, ActionController::HttpAuthentication::Basic.encode_credentials('username', 'password'))

      binding.break
      expect(described_class.matches_request?(request)).to_not be true
    end

    private

    # I'm not sure if there's a better way to get a mock rack request for
    # testing. Here we don't need a full request spec, but we do need enough to
    # check that the logic of these classes works.
    def mock_request(params, credentials = nil)
      request = ActionDispatch::Request.new({
        "REQUEST_METHOD"=>"POST",
        "SERVER_NAME"=>"example.org",
        "SERVER_PORT"=>"80",
        "SERVER_PROTOCOL"=>"HTTP/1.1",
        "rack.url_scheme"=>"http",
        "HTTP_HOST"=> "example.org",
        "ORIGINAL_FULLPATH" => "/test",
        "action_dispatch.remote_ip" => "127.0.0.1",
        "action_dispatch.request.query_parameters" => {},
        "action_dispatch.request.request_parameters" => params
      })

      unless credentials.nil?
        request.env["HTTP_AUTHORIZATION"] = credentials
      end

      request
    end
  end
end
