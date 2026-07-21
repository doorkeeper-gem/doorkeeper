# frozen_string_literal: true

require "spec_helper"
require "bcrypt"

RSpec.describe ::Doorkeeper::SecretStoring::BCrypt do
  let(:instance) { double("instance", token: "foo") }

  describe "#transform_secret" do
    it "creates a bcrypt password" do
      expect(described_class.transform_secret("foo")).to be_a BCrypt::Password
    end
  end

  describe "#restore_secret" do
    it "raises" do
      expect { described_class.restore_secret(instance, :token) }
        .to raise_error(NotImplementedError)
    end
  end

  describe "#allows_restoring_secrets?" do
    it "does not allow it" do
      expect(described_class.allows_restoring_secrets?).to be(false)
    end
  end

  describe "validate_for" do
    it "allows for valid model" do
      expect(described_class.validate_for(:application)).to be(true)
    end

    it "raises for invalid model" do
      expect { described_class.validate_for(:wat) }
        .to raise_error(ArgumentError, /can only be used for storing application secrets/)
      expect { described_class.validate_for(:token) }
        .to raise_error(ArgumentError, /can only be used for storing application secrets/)
    end

    it "raises when the bcrypt gem is not available" do
      allow(described_class).to receive(:bcrypt_present?).and_return(false)

      expect { described_class.validate_for(:application) }
        .to raise_error(ArgumentError, /requires the 'bcrypt' gem/)
    end
  end

  describe "bcrypt_present?" do
    it "is false when bcrypt cannot be loaded" do
      allow(described_class).to receive(:require).with("bcrypt").and_raise(LoadError)

      expect(described_class.bcrypt_present?).to be(false)
    end
  end

  describe "secret_matches?" do
    it "compares input with #transform_secret" do
      expect(described_class.secret_matches?("input", "input")).to be(false)

      password = BCrypt::Password.create("foobar")
      expect(described_class.secret_matches?("foobar", password.to_s)).to be(true)
    end
  end
end
