module RequestSpecHelper
  def i_should_see(content)
    page.should have_content(content)
  end

  def i_should_not_see(content)
    page.should have_no_content(content)
  end

  def i_should_be_on(path)
    current_path.should eq(path)
  end

  def url_should_have_param(param, value)
    current_params[param].should == value
  end

  def url_should_not_have_param(param)
    current_params.should_not have_key(param)
  end

  def current_params
    Rack::Utils.parse_query(current_uri.query)
  end

  def current_uri
    URI.parse(page.current_url)
  end

  def should_have_header(header, value)
    headers[header].should == value
  end

  def sign_in
    visit '/'
    click_on "Sign in"
  end

  def i_should_see_translated_error_message(key)
    i_should_see translated_error_message(key)
  end

  def translated_error_message(key)
    I18n.translate key, :scope => [:doorkeeper, :errors, :messages]
  end
end

RSpec.configuration.send :include, RequestSpecHelper, :type => :request
