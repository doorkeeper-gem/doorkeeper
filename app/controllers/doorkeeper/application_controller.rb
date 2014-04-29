module Doorkeeper
  class ApplicationController < ActionController::Base
    include Helpers::Controller

    helper 'doorkeeper/form_errors'
  end
end
