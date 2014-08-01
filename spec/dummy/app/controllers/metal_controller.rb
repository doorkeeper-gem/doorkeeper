class MetalController < ActionController::Metal
  include AbstractController::Callbacks
  include ActionController::Head
  include Doorkeeper::Rails::Helpers

  doorkeeper_for :all

  def index
    self.response_body = { ok: true }.to_json
  end
end
