module Doorkeeper::FormErrorsHelper
  def doorkeeper_errors_for(object, method)
    if object.errors[method].present?
      object.errors[method].map do |msg|
        content_tag(:span, class: 'help-block') do
          msg.capitalize
        end
      end.reduce(&:join).html_safe
    end
  end
end
