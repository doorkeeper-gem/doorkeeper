require 'test_helper'

module Tins
  require 'tins/xt/require_maybe'
  class RequireMaybeTest < Test::Unit::TestCase
    def test_require_maybe_failed
      executed = false
      require_maybe 'nix' do
        executed = true
      end
      assert executed, 'require did not fail'
    end

    def test_require_maybe_succeeded
      not_executed = true
      result = require_maybe 'tins' do
        not_executed = false
      end
      assert [ false, true ].include?(result)
      assert not_executed, 'require failed'
    end
  end
end
