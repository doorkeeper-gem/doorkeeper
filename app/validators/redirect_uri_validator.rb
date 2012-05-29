require 'uri'

class RedirectUriValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    uri = URI.parse(value)
    record.errors[attribute] << "cannot contain a fragment." unless uri.fragment.nil?
    record.errors[attribute] << "must be an absolute URL." if uri.scheme.nil? || uri.host.nil?
    record.errors[attribute] << "cannot contain a query parameter." unless uri.query.nil?
  rescue URI::InvalidURIError => e
    record.errors[attribute] << "must be a valid URI."
  end
end
