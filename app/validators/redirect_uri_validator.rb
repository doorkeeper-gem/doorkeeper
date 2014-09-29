require 'uri'

class RedirectUriValidator < ActiveModel::EachValidator
  def self.native_redirect_uri
    Doorkeeper.configuration.native_redirect_uri
  end

  def self.uses_force_ssl_in_redirect_uri?
    Doorkeeper.configuration.uses_force_ssl_in_redirect_uri?
  end

  def validate_each(record, attribute, value)
    if value.blank?
      record.errors.add(attribute, :blank)
    else
      value.split.each do |val|
        uri = ::URI.parse(val)
        return if native_redirect_uri?(uri)
        record.errors.add(attribute, :fragment_present) unless uri.fragment.nil?
        record.errors.add(attribute, :relative_uri) if uri.scheme.nil? || uri.host.nil?
        record.errors.add(attribute, :secured_uri) if has_invalid_ssl_uri_scheme(uri)
      end
    end
  rescue URI::InvalidURIError
    record.errors.add(attribute, :invalid_uri)
  end

  private

  def native_redirect_uri?(uri)
    self.class.native_redirect_uri.present? && uri.to_s == self.class.native_redirect_uri.to_s
  end

  def has_invalid_ssl_uri_scheme(uri)
    force_secured_redirect_uri? && (uri.scheme.nil? || uri.scheme != 'https')
  end

  def force_secured_redirect_uri?
    evaluates = self.class.uses_force_ssl_in_redirect_uri?
    options = Doorkeeper.configuration.force_ssl_in_redirect_uri_options
    if evaluates && options
      if_method = options.delete(:if)
      unless_method = options.delete(:unless)
      evaluates &= if_method.call if if_method && if_method.is_a?(Proc)
      evaluates &= !unless_method.call if unless_method && unless_method.is_a?(Proc)
    end
    evaluates
  end
end
