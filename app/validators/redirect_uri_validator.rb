require 'uri'

class RedirectUriValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    uri = ::URI.parse(value)
    record.errors.add(attribute, :fragment_present) unless uri.fragment.nil?
    record.errors.add(attribute, :relative_uri) if uri.scheme.nil? || uri.host.nil?
    record.errors.add(attribute, :has_query_parameter) unless uri.query.nil?
  rescue URI::InvalidURIError => e
    record.errors.add(attribute, :invalid_uri)
  end
end
