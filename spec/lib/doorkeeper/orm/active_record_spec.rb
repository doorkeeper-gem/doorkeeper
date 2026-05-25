# frozen_string_literal: true

require "spec_helper"

if DOORKEEPER_ORM == :active_record
  RSpec.describe Doorkeeper::Orm::ActiveRecord do
    describe ".initialize_configured_associations" do
      it "uses ActiveSupport.on_load(:active_record) to defer model loading" do
        expect(ActiveSupport).to receive(:on_load).with(:active_record)
        described_class.initialize_configured_associations
      end
    end

    # Reproduction test for https://github.com/doorkeeper-gem/doorkeeper/issues/1703
    #
    # Without the on_load wrapper, calling initialize_configured_associations
    # eagerly triggers constantize on model class names (via access_token_model,
    # access_grant_model, etc.), which forces ActiveRecord to load before
    # config.active_record.* settings have been applied. This test verifies
    # that the on_load block does NOT execute eagerly at registration time.
    #
    # See also: https://github.com/ngan/doorkeeper-activerecord-load-issue
    describe "deferral of model loading (issue #1703)" do
      it "does not call config model accessors at registration time" do
        # Stub on_load to capture the block WITHOUT executing it,
        # simulating the state before ActiveRecord is fully initialized.
        allow(ActiveSupport).to receive(:on_load).with(:active_record)

        expect(Doorkeeper.config).not_to receive(:application_model)
        expect(Doorkeeper.config).not_to receive(:access_token_model)
        expect(Doorkeeper.config).not_to receive(:access_grant_model)

        described_class.initialize_configured_associations
      end

      it "calls config model accessors only when the on_load hook fires" do
        deferred_block = nil

        allow(ActiveSupport).to receive(:on_load).with(:active_record) do |*, &block|
          deferred_block = block
        end

        described_class.initialize_configured_associations

        # Block was captured but not yet executed
        expect(deferred_block).not_to be_nil

        # Now simulate ActiveRecord finishing initialization by executing the block
        expect(Doorkeeper.config).to receive(:enable_application_owner?).and_return(false)
        expect(Doorkeeper.config).to receive(:access_grant_model).and_return(Doorkeeper::AccessGrant)
        expect(Doorkeeper.config).to receive(:access_token_model).and_return(Doorkeeper::AccessToken)

        deferred_block.call
      end
    end

    describe "STI (Single Table Inheritance) support" do
      # Ensure STI subclasses work correctly with the ActiveSupport.on_load hook.
      # See: https://github.com/doorkeeper-gem/doorkeeper/issues/1703
      #      https://github.com/doorkeeper-gem/doorkeeper/issues/1513

      context "when application_class is a STI subclass of Doorkeeper::Application" do
        let!(:custom_application_class) do
          Class.new(Doorkeeper::Application) do
            def self.name
              "CustomStiApplication"
            end
          end
        end

        before do
          stub_const("CustomStiApplication", custom_application_class)

          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            enable_application_owner
            application_class "CustomStiApplication"
          end

          Doorkeeper.run_orm_hooks
        end

        it "includes Ownership module in the STI subclass" do
          expect(CustomStiApplication.ancestors).to include(Doorkeeper::Models::Ownership)
        end

        it "STI subclass responds to owner association" do
          instance = CustomStiApplication.new
          expect(instance).to respond_to(:owner)
        end
      end

      context "when access_token_class is a STI subclass of Doorkeeper::AccessToken" do
        let!(:custom_token_class) do
          Class.new(Doorkeeper::AccessToken) do
            def self.name
              "CustomStiAccessToken"
            end
          end
        end

        before do
          stub_const("CustomStiAccessToken", custom_token_class)

          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            access_token_class "CustomStiAccessToken"
          end

          Doorkeeper.run_orm_hooks
        end

        it "includes PolymorphicResourceOwner::ForAccessToken in the STI subclass" do
          expect(CustomStiAccessToken.ancestors).to include(
            Doorkeeper::Models::PolymorphicResourceOwner::ForAccessToken,
          )
        end
      end

      context "when access_grant_class is a STI subclass of Doorkeeper::AccessGrant" do
        let!(:custom_grant_class) do
          Class.new(Doorkeeper::AccessGrant) do
            def self.name
              "CustomStiAccessGrant"
            end
          end
        end

        before do
          stub_const("CustomStiAccessGrant", custom_grant_class)

          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            access_grant_class "CustomStiAccessGrant"
          end

          Doorkeeper.run_orm_hooks
        end

        it "includes PolymorphicResourceOwner::ForAccessGrant in the STI subclass" do
          expect(CustomStiAccessGrant.ancestors).to include(
            Doorkeeper::Models::PolymorphicResourceOwner::ForAccessGrant,
          )
        end
      end
    end

    # Regression test for https://github.com/doorkeeper-gem/doorkeeper/issues/1828
    #
    # `rails db:seed` (and any flow that runs without eager_load) can autoload
    # ActiveRecord::Base lazily from inside `class ApplicationRecord < ActiveRecord::Base`.
    # When AR::Base finishes loading, `run_load_hooks(:active_record)` fires —
    # while ApplicationRecord is still mid-evaluation, so its constant is not
    # yet defined. Without the fix, the on_load callback registered by
    # `initialize_configured_associations` (post-#1804) calls `constantize` on
    # a user-configured class that inherits from ApplicationRecord, which
    # raises `NameError: uninitialized constant ApplicationRecord`.
    #
    # This can't be reproduced inside the dummy app because AR::Base loads at
    # spec-helper time, so we drive a fresh subprocess that replays the
    # autoload chain end-to-end.
    describe "issue #1828 — re-entrant on_load(:active_record) during ApplicationRecord autoload" do
      it "does not raise NameError on uninitialized constant ApplicationRecord" do
        require "tmpdir"
        require "English"
        require "bundler"

        doorkeeper_lib  = File.expand_path("../../../../lib", __dir__)
        # Use the same Gemfile the parent is running under so this passes across
        # the Appraisal matrix (rails_7_0.gemfile pins rspec-rails ~> 5.0 etc.).
        gemfile         = Bundler.default_gemfile.to_s

        Dir.mktmpdir("doorkeeper-1828-") do |dir|
          File.write(File.join(dir, "application_record.rb"), <<~RUBY)
            class ApplicationRecord < ActiveRecord::Base
              self.abstract_class = true if respond_to?(:abstract_class=)
            end
          RUBY

          File.write(File.join(dir, "user.rb"),       "class User < ApplicationRecord; end\n")
          File.write(File.join(dir, "foo_token.rb"),  "class FooToken < ApplicationRecord; end\n")
          File.write(File.join(dir, "foo_grant.rb"),  "class FooGrant < ApplicationRecord; end\n")

          File.write(File.join(dir, "active_record_base_stub.rb"), <<~RUBY)
            module ActiveRecord
              class Base
                def self.abstract_class=(_); end
              end
            end
            ActiveSupport.run_load_hooks(:active_record, ActiveRecord::Base)
          RUBY

          File.write(File.join(dir, "run.rb"), <<~RUBY)
            $LOAD_PATH.unshift #{doorkeeper_lib.inspect}

            require "active_support"
            require "active_support/core_ext/string/inflections"

            module ActiveRecord
              autoload :Base, #{File.join(dir, "active_record_base_stub.rb").inspect}
            end

            Object.autoload :User,              #{File.join(dir, "user.rb").inspect}
            Object.autoload :ApplicationRecord, #{File.join(dir, "application_record.rb").inspect}
            Object.autoload :FooToken,          #{File.join(dir, "foo_token.rb").inspect}
            Object.autoload :FooGrant,          #{File.join(dir, "foo_grant.rb").inspect}

            # Minimal Doorkeeper namespace so we can load `doorkeeper/orm/active_record.rb`
            # without pulling Rails (and therefore without pre-loading AR::Base).
            module Doorkeeper
              module Models
                module Ownership; end
                module PolymorphicResourceOwner
                  module ForAccessGrant; end
                  module ForAccessToken; end
                end
              end

              def self.config
                @config ||= Config.new
              end

              class Config
                def enable_application_owner?; false; end
                def access_grant_model; FooGrant; end
                def access_token_model; FooToken; end
              end
            end

            require "doorkeeper/orm/active_record"

            # Simulate the `config.to_prepare` block in the engine.
            Doorkeeper::Orm::ActiveRecord.run_hooks

            # Simulate seed-style host-app code referencing a model after boot.
            User

            puts "OK"
          RUBY

          env = { "BUNDLE_GEMFILE" => gemfile }
          cmd = ["bundle", "exec", "ruby", File.join(dir, "run.rb")]
          output = IO.popen(env, cmd, err: [:child, :out], &:read)
          status = $CHILD_STATUS.exitstatus

          expect(status).to(
            eq(0),
            "Subprocess exited #{status} — issue #1828 fix not in place.\n" \
            "Output:\n#{output}",
          )
          expect(output).to include("OK")
        end
      end
    end
  end
end
