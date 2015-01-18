require 'spec_helper'
require 'active_support/core_ext/object/blank'
require 'doorkeeper/models/concerns/revocable'

describe 'Revocable' do
  subject do
    Class.new do
      include Doorkeeper::Models::Revocable
    end.new
  end

  describe :revoke do
    it 'updates :revoked_at attribute with current time' do
      clock = double now: double
      expect(subject).to receive(:update_attribute).with(:revoked_at, clock.now)
      subject.revoke(clock)
    end
  end

  describe :revoked? do
    it 'is revoked if :revoked_at has passed' do
      allow(subject).to receive(:revoked_at).and_return(DateTime.now - 1000)
      expect(subject).to be_revoked
    end

    it 'is not revoked if :revoked_at has not passed' do
      allow(subject).to receive(:revoked_at).and_return(DateTime.now + 1000)
      expect(subject).not_to be_revoked
    end

    it 'is not revoked if :revoked_at is not set' do
      allow(subject).to receive(:revoked_at).and_return(nil)
      expect(subject).not_to be_revoked
    end
  end

  describe :revoke_previous_refresh_token! do
    subject { FactoryGirl.build(:access_token, :previous_refresh_token => 'old_refresh_token') }
    previous_token = FactoryGirl.build(:access_token)

    it 'revokes the previous token if present and sets the attribute :previous_refresh_token to nil' do
      expect(Doorkeeper::AccessToken).to receive(:from_refresh_token).with(subject.previous_refresh_token).and_return(previous_token)
      expect(previous_token).to receive(:revoke)
      expect(subject).to receive(:update_attribute).with(:previous_refresh_token, nil)
      subject.revoke_previous_refresh_token!
    end

    it 'does nothing if the previous refresh token is nil' do
      subject.previous_refresh_token = nil
      expect(subject).to_not receive(:update_attribute).with(:previous_refresh_token, nil)
      subject.revoke_previous_refresh_token!
    end

    it 'sets the attribute :previous_refresh_token to nil if the previous refresh token does not exist' do
      expect(Doorkeeper::AccessToken).to receive(:from_refresh_token).with(subject.previous_refresh_token).and_return(nil)
      expect(subject).to receive(:update_attribute).with(:previous_refresh_token, nil)
      subject.revoke_previous_refresh_token!
    end
  end
end
