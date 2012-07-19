require 'uri'

class RedirectUriValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    uri = URI.parse(value)
    record.errors[attribute] << I18n.t('cannot_contain_fragment', :scope => [:doorkeeper, :errors, :validations]) unless uri.fragment.nil?
    record.errors[attribute] << I18n.t('must_be_an_absolute_url', :scope => [:doorkeeper, :errors, :validations]) if uri.scheme.nil? || uri.host.nil?
    record.errors[attribute] << I18n.t('cannot_cointain_query_parameter', :scope => [:doorkeeper, :errors, :validations]) unless uri.query.nil?
  rescue URI::InvalidURIError => e
    record.errors[attribute] << I18n.t('must_be_a_valid_uri', :scope => [:doorkeeper, :errors, :validations])
  end
end
