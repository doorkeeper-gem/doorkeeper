module RequestSpecHelper
  def i_should_see(content)
    page.should have_content(content)
  end

  def i_should_be_on(path)
    current_path.should eq(path)
  end

  def i_should_be_on_url(path)
    page.current_url.should == path
  end
end
