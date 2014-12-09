module Doorkeeper
  class ApplicationController < ActionController::Base
    include Helpers::Controller

    helper 'doorkeeper/form_errors'

    if ::Rails.version.to_i < 4
      protect_from_forgery
    else
      protect_from_forgery with: :exception
    end
  end
end
