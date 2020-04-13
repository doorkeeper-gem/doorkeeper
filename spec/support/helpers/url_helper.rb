# frozen_string_literal: true

module UrlHelper
  def token_endpoint_url(options = {})
    parameters = {
      code: options[:code],
      client_id: options[:client_id] || options[:client].try(:uid),
      client_secret: options[:client_secret] || options[:client].try(:secret),
      redirect_uri: options[:redirect_uri] || options[:client].try(:redirect_uri),
      grant_type: options[:grant_type] || "authorization_code",
      code_verifier: options[:code_verifier],
      code_challenge_method: options[:code_challenge_method],
    }.reject { |_, v| v.blank? }
    "/oauth/token?#{build_query(parameters)}"
  end

  def password_token_endpoint_url(options = {})
    parameters = {
      code: options[:code],
      client_id: options[:client_id] || options[:client].try(:uid),
      client_secret: options[:client_secret] || options[:client].try(:secret),
      username: options[:resource_owner_username] || options[:resource_owner].try(:name),
      password: options[:resource_owner_password] || options[:resource_owner].try(:password),
      scope: options[:scope],
      grant_type: "password",
    }.reject { |_, v| v.blank? }
    "/oauth/token?#{build_query(parameters)}"
  end

  def authorization_endpoint_url(options = {})
    parameters = {
      client_id: options[:client_id] || options[:client].try(:uid),
      redirect_uri: options[:redirect_uri] || options[:client].try(:redirect_uri),
      response_type: options[:response_type] || "code",
      scope: options[:scope],
      state: options[:state],
      code_challenge: options[:code_challenge],
      code_challenge_method: options[:code_challenge_method],
    }.reject { |_, v| v.blank? }
    "/oauth/authorize?#{build_query(parameters)}"
  end

  def refresh_token_endpoint_url(options = {})
    parameters = {
      refresh_token: options[:refresh_token],
      client_id: options[:client_id] || options[:client].try(:uid),
      client_secret: options[:client_secret] || options[:client].try(:secret),
      grant_type: options[:grant_type] || "refresh_token",
    }.reject { |_, v| v.blank? }
    "/oauth/token?#{build_query(parameters)}"
  end

  def revocation_token_endpoint_url
    "/oauth/revoke"
  end

  def build_query(hash)
    Rack::Utils.build_query(hash)
  end
end

RSpec.configuration.send :include, UrlHelper
