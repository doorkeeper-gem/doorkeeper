# frozen_string_literal: true

module Doorkeeper
  class DiscoveryController < Doorkeeper::ApplicationMetalController
    def show
      headers.merge!(discovery_response.headers)
      render json: discovery_response.body,
             status: discovery_response.status
    end

    private

    def discovery_response
      @discovery_response ||= Doorkeeper::OAuth::DiscoveryResponse.new(
        root_url,
        -> (**args) { url_for(**args) }
      )
    end
  end
end
