module Doorkeeper::DashboardHelper
  def doorkeeper_errors_for(object, method)
    if object.errors[method].present?
      object.errors[method].map do |msg|
        content_tag(:span, class: 'help-block') do
          msg.capitalize
        end
      end.reduce(&:join).html_safe
    end
  end

  def doorkeeper_submit_path(application)
    application.persisted? ? oauth_application_path(application) : oauth_applications_path
  end

  def doorkeeper_scope_list
     (Doorkeeper.configuration.default_scopes.to_a | Doorkeeper.configuration.scopes.to_a).reject(&:empty?)
  end
end
