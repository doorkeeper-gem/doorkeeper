require 'spec_helper'

describe 'Application' do
  let(:new_application) { Factory.build(:application) }

  it 'is valid given valid attributes' do
    new_application.should be_valid
  end

  it 'is invalid without a name' do
    new_application.name = nil
    new_application.should_not be_valid
  end

  it 'generates uid on create' do
    new_application.uid.should be_nil
    new_application.save
    new_application.uid.should_not be_nil
  end

  it 'is invalid without uid' do
    new_application.save
    new_application.uid = nil
    new_application.should_not be_valid
  end

  it 'is invalid without redirect_uri' do
    new_application.save
    new_application.redirect_uri = nil
    new_application.should_not be_valid
  end

  it 'is invalid with a redirect_uri that is relative' do
    new_application.save
    new_application.redirect_uri = "/abcd"
    new_application.should_not be_valid
  end

  it 'is invalid with a redirect_uri that has a fragment' do
    new_application.save
    new_application.redirect_uri = "http://example.com/abcd#xyz"
    new_application.should_not be_valid
  end

  it 'is invalid with a redirect_uri that has a query parameter' do
    new_application.save
    new_application.redirect_uri = "http://example.com/abcd?xyz=123"
    new_application.should_not be_valid
  end

  it 'checks uniqueness of uid' do
    app1 = Factory(:application)
    app2 = Factory(:application)
    app2.uid = app1.uid
    app2.should_not be_valid
  end

  it 'generate secret on create' do
    new_application.secret.should be_nil
    new_application.save
    new_application.secret.should_not be_nil
  end

  it 'is invalid without secret' do
    new_application.save
    new_application.secret = nil
    new_application.should_not be_valid
  end
end
