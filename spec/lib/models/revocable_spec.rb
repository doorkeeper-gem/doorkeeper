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
      utc = double utc: double
      clock = double now: utc
      expect(subject).to receive(:update_attribute).with(:revoked_at, clock.now.utc)
      subject.revoke(clock)
    end
  end

  describe :revoked? do
    it 'is revoked if :revoked_at has passed' do
      allow(subject).to receive(:revoked_at).and_return(Time.now.utc - 1000)
      expect(subject).to be_revoked
    end

    it 'is not revoked if :revoked_at has not passed' do
      allow(subject).to receive(:revoked_at).and_return(Time.now.utc + 1000)
      expect(subject).not_to be_revoked
    end

    it 'is not revoked if :revoked_at is not set' do
      allow(subject).to receive(:revoked_at).and_return(nil)
      expect(subject).not_to be_revoked
    end
  end
end
