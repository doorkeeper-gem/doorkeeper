require 'uri'

class RedirectUriValidator < ActiveModel::EachValidator
  def self.test_redirect_uri
    Doorkeeper.configuration.test_redirect_uri
  end

  def validate_each(record, attribute, value)
    return if value.nil? && !Doorkeeper.configuration.require_redirect_uri
    uri = ::URI.parse(value)
    return if test_redirect_uri?(uri)
    record.errors.add(attribute, :fragment_present) unless uri.fragment.nil?
    record.errors.add(attribute, :relative_uri) if uri.scheme.nil? || uri.host.nil?
    record.errors.add(attribute, :has_query_parameter) unless uri.query.nil?
  rescue URI::InvalidURIError => e
    record.errors.add(attribute, :invalid_uri)
  end

private

  def test_redirect_uri?(uri)
    self.class.test_redirect_uri.present? && uri.to_s == self.class.test_redirect_uri.to_s
  end
end
