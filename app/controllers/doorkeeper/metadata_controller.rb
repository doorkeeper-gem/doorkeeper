# frozen_string_literal: true

module Doorkeeper
  class MetadataController < Doorkeeper::ApplicationMetalController
    def show
      headers.merge!(metadata_response.headers)
      render json: metadata_response.body,
             status: metadata_response.status
    end

    private

    def metadata_response
      @metadata_response ||= Doorkeeper::OAuth::MetadataResponse.new(
        request.base_url,
        ->(**args) { url_for(**args) },
      )
    end
  end
end
