module Doorkeeper
  class TokensController < ApplicationController
    def create
      token_request = OAuth::AccessTokenRequest.new(params[:code], params)
      if token_request.authorize
        render :json => token_request.authorization
      else
        render :json => token_request.error
      end
    end
  end
end
