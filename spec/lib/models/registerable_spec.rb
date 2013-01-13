require 'spec_helper_integration'

describe Doorkeeper::Models::Registerable do
  subject do
    FactoryGirl.create :application
  end

  it 'requires redirect_uri to be present' do
    subject.redirect_uri = nil
    subject.should_not be_valid
  end

  it 'generates uid on creation' do
    subject.uid.should_not be_nil
  end

  it 'requires secret on creation' do
    subject.secret.should_not be_nil
  end

  it 'does not change uid on update' do
    expect { subject.save }.to_not change { subject.reload.uid }
  end

  it 'does not change secret on update' do
    expect { subject.save }.to_not change { subject.reload.secret }
  end

  context 'validations' do
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
end
