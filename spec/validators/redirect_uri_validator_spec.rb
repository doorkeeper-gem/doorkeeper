require 'spec_helper'
require 'active_model'
require 'validators/redirect_uri_validator'

describe RedirectUriValidator do
  subject do
    Class.new do
      include ActiveModel::Validations
      attr_accessor :uri
      validates :uri, :redirect_uri => true
    end.new
  end

  it 'is valid when the uri is a uri' do
    subject.uri = "http://example.com/callback"
    subject.should be_valid
  end

  it 'is invalid when the uri is not a uri' do
    subject.uri = 123
    subject.should_not be_valid
    subject.errors[:uri].first.should == "must be a valid URI."
  end

  it 'is invalid when the uri is relative' do
    subject.uri = "/abcd"
    subject.should_not be_valid
    subject.errors[:uri].first.should == "must be an absolute URL."
  end

  it 'is invalid when the uri has a fragment' do
    subject.uri = "http://example.com/abcd#xyz"
    subject.should_not be_valid
    subject.errors[:uri].first.should == "cannot contain a fragment."
  end

  it 'is invalid when the uri has a query parameter' do
    subject.uri = "http://example.com/abcd?xyz=123"
    subject.should_not be_valid
    subject.errors[:uri].first.should == "cannot contain a query parameter."
  end
end
