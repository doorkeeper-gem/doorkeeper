# frozen_string_literal: true

module RequestSpecHelper
  def i_am_logged_in
    allow(Doorkeeper.configuration).to receive(:authenticate_admin).and_return(->(*) {})
  end

  def i_should_see(content)
    expect(page).to have_content(content)
  end

  def i_should_not_see(content)
    expect(page).to have_no_content(content)
  end

  def i_should_be_on(path)
    expect(page).to have_current_path(path, ignore_query: true)
  end

  def url_should_have_param(param, value)
    expect(current_params[param]).to eq(value)
  end

  def url_should_not_have_param(param)
    expect(current_params).not_to have_key(param)
  end

  def current_params
    Rack::Utils.parse_query(current_uri.query)
  end

  def current_uri
    URI.parse(page.current_url)
  end

  def request_response
    respond_to?(:response) ? response : page.driver.response
  end

  def json_response
    JSON.parse(request_response.body)
  end

  def should_have_status(status)
    expect(page.driver.response.status).to eq(status)
  end

  def with_access_token_header(token)
    with_header "Authorization", "Bearer #{token}"
  end

  def with_header(header, value)
    page.driver.header(header, value)
  end

  def basic_auth_header_for_client(client)
    ActionController::HttpAuthentication::Basic.encode_credentials client.uid, client.secret
  end

  def sign_in
    visit "/"
    click_on "Sign in"
  end

  def create_access_token(authorization_code, client, code_verifier = nil)
    page.driver.post token_endpoint_url(code: authorization_code, client: client, code_verifier: code_verifier)
  end

  def i_should_see_translated_error_message(key)
    i_should_see translated_error_message(key)
  end

  def i_should_not_see_translated_error_message(key)
    i_should_not_see translated_error_message(key)
  end

  def translated_error_message(key)
    I18n.translate(key, scope: %i[doorkeeper errors messages])
  end

  def i_should_see_translated_invalid_request_error_message(key, value)
    i_should_see translated_invalid_request_error_message(key, value)
  end

  def translated_invalid_request_error_message(key, value)
    I18n.translate key, scope: %i[doorkeeper errors messages invalid_request], value: value
  end

  def response_status_should_be(status)
    expect(request_response.status.to_i).to eq(status)
  end
end

RSpec.configuration.send :include, RequestSpecHelper
