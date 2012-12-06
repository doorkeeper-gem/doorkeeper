require 'spec_helper'
require 'timecop'
require 'active_support/time'
require 'doorkeeper/models/expirable'

describe 'Expirable' do
  subject do
    Class.new do
      include Doorkeeper::Models::Expirable
    end.new
  end

  before do
    subject.stub :created_at => 1.minute.ago
  end

  describe :expired? do
    it "is not expired if time has not passed" do
      subject.stub :expires_in => 2.minutes
      subject.should_not be_expired
    end

    it "is expired if time has passed" do
      subject.stub :expires_in => 10.seconds
      subject.should be_expired
    end

    it "is not expired if expires_in is not set" do
      subject.stub :expires_in => nil
      subject.should_not be_expired
    end
  end

  describe :expires_in_seconds do
    it "should return the amount of time remaining until the token is expired" do
      subject.stub :expires_in => 2.minutes
      subject.expires_in_seconds.should == 60 
    end

    it "should return 0 when expired" do
      subject.stub :expires_in => 30.seconds
      subject.expires_in_seconds.should == 0 
    end

    it "should return nil when expires_in is nil" do
      subject.stub :expires_in => nil
      subject.expires_in_seconds.should be_nil
    end
    
  end
end
