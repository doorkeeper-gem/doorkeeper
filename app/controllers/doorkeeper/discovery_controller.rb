# frozen_string_literal: true

module Doorkeeper
  class DiscoveryController < Doorkeeper::ApplicationMetalController
    def show
      render json: {}, status: 200
    end
  end
end
