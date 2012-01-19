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

  describe :time_left do
    it "returns the time in seconds since it was created" do
      Timecop.freeze(Time.now) do
        subject.stub :created_at => Time.now, :expires_in => 10.seconds
        subject.time_left.should == 10.seconds
      end
    end

    it "returns 0 if token has expired" do
      Timecop.freeze(Time.now + 1.minute) do
        subject.stub :created_at => 1.minutes.ago, :expires_in => 10.seconds
        subject.time_left.should == 0
      end
    end
  end
end
