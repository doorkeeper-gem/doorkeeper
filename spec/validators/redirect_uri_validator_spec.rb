require 'spec_helper_integration'

describe RedirectUriValidator do
  subject do
    FactoryGirl.create(:application)
  end

  it 'is valid when the uri is a uri' do
    subject.redirect_uri = "http://example.com/callback"
    subject.should be_valid
  end

  it 'accepts test redirect uri' do
    subject.redirect_uri = 'urn:ietf:wg:oauth:2.0:oob'
    subject.should be_valid
  end

  it 'rejects if test uri is disabled' do
    RedirectUriValidator.stub :test_redirect_uri => nil
    subject.redirect_uri = "urn:some:test"
    subject.should_not be_valid
  end

  it 'is invalid when the uri is not a uri' do
    subject.redirect_uri = ']'
    subject.should_not be_valid
    subject.errors[:redirect_uri].first.should == "must be a valid URI."
  end

  it 'is invalid when the uri is relative' do
    subject.redirect_uri = "/abcd"
    subject.should_not be_valid
    subject.errors[:redirect_uri].first.should == "must be an absolute URI."
  end

  it 'is invalid when the uri has a fragment' do
    subject.redirect_uri = "http://example.com/abcd#xyz"
    subject.should_not be_valid
    subject.errors[:redirect_uri].first.should == "cannot contain a fragment."
  end

  it 'is invalid when the uri has a query parameter' do
    subject.redirect_uri = "http://example.com/abcd?xyz=123"
    subject.should_not be_valid
    subject.errors[:redirect_uri].first.should == "cannot contain a query parameter."
  end
end
