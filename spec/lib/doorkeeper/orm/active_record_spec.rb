# frozen_string_literal: true

require "spec_helper"

if DOORKEEPER_ORM == :active_record
  RSpec.describe Doorkeeper::Orm::ActiveRecord do
    describe ".run_hooks" do
      # The orm hook used to register an `ActiveSupport.on_load(:active_record)`
      # block that constantized the configured model classes (#1804). That
      # callback could fire re-entrantly during `class ApplicationRecord <
      # ActiveRecord::Base` autoload and raise `NameError: uninitialized
      # constant ApplicationRecord` (#1828). The callback is gone now — the
      # model concerns it used to include are wired up from each Mixin's
      # `included` block instead — so `run_hooks` is a no-op and must not
      # touch ActiveRecord at all.
      it "does not register any on_load(:active_record) callback" do
        expect(ActiveSupport).not_to receive(:on_load).with(:active_record)
        described_class.run_hooks
      end

      it "does not constantize any configured model class" do
        expect(Doorkeeper.config).not_to receive(:application_model)
        expect(Doorkeeper.config).not_to receive(:access_grant_model)
        expect(Doorkeeper.config).not_to receive(:access_token_model)
        described_class.run_hooks
      end
    end

    describe "automatic mixin concerns" do
      # The model concerns used to be included by `run_hooks` via an
      # `on_load(:active_record)` callback. They are now included by each
      # Mixin's `included` block at parent-class autoload time, which both
      # avoids the early-AR-load regression #1804 fixed (#1703) and removes
      # the re-entrant on_load surface that #1828 stumbled into.

      it "includes PolymorphicResourceOwner::ForAccessGrant in Doorkeeper::AccessGrant" do
        expect(Doorkeeper::AccessGrant.ancestors).to include(
          Doorkeeper::Models::PolymorphicResourceOwner::ForAccessGrant,
        )
      end

      it "includes PolymorphicResourceOwner::ForAccessToken in Doorkeeper::AccessToken" do
        expect(Doorkeeper::AccessToken.ancestors).to include(
          Doorkeeper::Models::PolymorphicResourceOwner::ForAccessToken,
        )
      end

      it "includes Ownership in Doorkeeper::Application" do
        expect(Doorkeeper::Application.ancestors).to include(Doorkeeper::Models::Ownership)
      end
    end

    describe "STI (Single Table Inheritance) support" do
      # Ensure STI subclasses inherit the model concerns through the standard
      # Ruby ancestor chain — the parent class includes the Mixin (and thus the
      # concerns) at autoload time, so any subclass automatically picks them
      # up. See: https://github.com/doorkeeper-gem/doorkeeper/issues/1703
      #         https://github.com/doorkeeper-gem/doorkeeper/issues/1513

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
        end

        it "inherits Ownership from Doorkeeper::Application" do
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
        end

        it "inherits PolymorphicResourceOwner::ForAccessToken from Doorkeeper::AccessToken" do
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
        end

        it "inherits PolymorphicResourceOwner::ForAccessGrant from Doorkeeper::AccessGrant" do
          expect(CustomStiAccessGrant.ancestors).to include(
            Doorkeeper::Models::PolymorphicResourceOwner::ForAccessGrant,
          )
        end
      end
    end

    # Regression test for https://github.com/doorkeeper-gem/doorkeeper/issues/1828
    #
    # `rails db:seed` (and any flow that runs without eager_load) can autoload
    # ActiveRecord::Base lazily from inside `class ApplicationRecord <
    # ActiveRecord::Base`. The previous fix (#1804) registered an
    # `on_load(:active_record)` callback that would fire mid-load and raise
    # `NameError: uninitialized constant ApplicationRecord`. The refactor
    # removes the on_load surface entirely: model concerns are now included
    # from each Mixin's `included` block. This subprocess test boots
    # `doorkeeper/orm/active_record` in a fresh process and replays the
    # autoload chain to prove nothing in the orm load path registers an
    # on_load callback (or otherwise depends on AR being pre-loaded).
    describe "issue #1828 — autoloading without ActiveSupport.on_load(:active_record)" do
      it "does not raise NameError on uninitialized constant ApplicationRecord" do
        require "tmpdir"
        require "English"
        require "bundler"

        doorkeeper_lib = File.expand_path("../../../../lib", __dir__)
        # Use the same Gemfile the parent is running under so this passes across
        # the Appraisal matrix (rails_7_0.gemfile pins rspec-rails ~> 5.0 etc.).
        gemfile = Bundler.default_gemfile.to_s

        Dir.mktmpdir("doorkeeper-1828-") do |dir|
          File.write(File.join(dir, "application_record.rb"), <<~RUBY)
            class ApplicationRecord < ActiveRecord::Base
              self.abstract_class = true if respond_to?(:abstract_class=)
            end
          RUBY

          File.write(File.join(dir, "user.rb"),      "class User < ApplicationRecord; end\n")
          File.write(File.join(dir, "foo_token.rb"), "class FooToken < ApplicationRecord; end\n")
          File.write(File.join(dir, "foo_grant.rb"), "class FooGrant < ApplicationRecord; end\n")

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

            # Simulate the `config.to_prepare` block in the engine. This is a
            # no-op after the refactor and must NOT trigger any AR autoload
            # or on_load callback.
            Doorkeeper::Orm::ActiveRecord.run_hooks

            # Simulate seed-style host-app code referencing a model after
            # boot. This triggers the ApplicationRecord autoload chain that
            # used to re-entrantly fire the on_load(:active_record)
            # callback. With on_load removed, the chain completes cleanly.
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
