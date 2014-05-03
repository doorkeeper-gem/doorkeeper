class MetalController < ActionController::Metal
  include AbstractController::Callbacks
  include ActionController::Head
  include Doorkeeper::Helpers::Filter

  doorkeeper_for :all

  def index
    self.response_body = { ok: true }.to_json
  end
end
