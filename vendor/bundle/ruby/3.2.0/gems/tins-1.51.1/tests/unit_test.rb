require 'test_helper'

module Tins
  class UnitTest < Test::Unit::TestCase
    include Tins::Unit

    def test_prefixes
      assert_equal %i[ foo ], prefixes(%i[ foo ])
      assert_equal Tins::Unit::PREFIX_LC, prefixes(1000)
      assert_equal Tins::Unit::PREFIX_LC, prefixes(:lc)
      assert_equal Tins::Unit::PREFIX_LC, prefixes(:lowercase)
      assert_equal Tins::Unit::PREFIX_UC, prefixes(1024)
      assert_equal Tins::Unit::PREFIX_UC, prefixes(:uc)
      assert_equal Tins::Unit::PREFIX_UC, prefixes(:uppercase)
      assert_equal Tins::Unit::PREFIX_F, prefixes(0.001)
      assert_equal Tins::Unit::PREFIX_F, prefixes(:f)
      assert_equal Tins::Unit::PREFIX_F, prefixes(:fraction)
      assert_equal Tins::Unit::PREFIX_F, prefixes(:si_greek)
      assert_equal Tins::Unit::PREFIX_SI_UC, prefixes(:si_uc)
      assert_equal Tins::Unit::PREFIX_SI_UC, prefixes(:si_uppercase)
      assert_equal Tins::Unit::PREFIX_IEC_UC, prefixes(:iec_uc)
      assert_equal Tins::Unit::PREFIX_IEC_UC, prefixes(:iec_uppercase)
      assert_equal nil, prefixes(:nix)
    end

    def test_0_format
      assert_equal '0 b', format(0, format: '%d %U')
    end

    def test_format_multipliers
      assert_equal '23 Kb',
        format(23 * 1024, format: '%d %U')
      assert_equal '-23 Kb',
        format(-23 * 1024, format: '%d %U')
      assert_equal '23.1 Kb',
        format(23 * 1024 + 111, format: '%.1f %U')
      assert_equal 'Kbps: 23',
        format(23 * 1024, format: '%U: %d', unit: 'bps')
      assert_equal 'kbps: 23.12',
        format(23 * 1000 + 120, prefix: 1000, format: '%U: %.2f', unit: 'bps')
    end

    def test_format_fractions
      assert_equal '0.123 mS',
        format(0.000_123, format: '%.3f %U', prefix: 0.001, unit: ?S)
      assert_equal '0.123 µF',
        format(0.000_000_123, format: '%.3f %U', prefix: :f, unit: ?F)
    end

    def test_format_si_multipliers
      assert_equal '23 KHz',
        format(23 * 1000, format: '%d %U', prefix: :si_uc, unit: 'Hz')
      assert_equal '-23 KHz',
        format(-23 * 1000, format: '%d %U', prefix: :si_uc, unit: 'Hz')
      assert_equal '23.1 KHz',
        format(23 * 1000 + 111, format: '%.1f %U', prefix: :si_uc, unit: 'Hz')
      assert_equal 'KHz: 23',
        format(23 * 1000, format: '%U: %d', prefix: :si_uc, unit: 'Hz')
      assert_equal 'KHz: 23.12',
        format(23 * 1000 + 120, prefix: :si_uc, format: '%U: %.2f', unit: 'Hz')
    end

    def test_parse
      assert_in_delta 17_301_504, parse('16.5 Mb').to_i, 1e-5
      assert_in_delta 16_500_000, parse('16.5 mbps', unit: 'bps').to_i, 1e-5
      assert_in_delta 0.1234e-5, parse('1.234 µS', unit: ?S, prefix: :f).to_s, 1e-5
      assert_raise(ParserError) { parse('16.5 nix', unit: ?b) }
      assert_raise(ParserError) { parse('nix Mb') }
      assert_in_delta 17_301_504, parse('16.5 % Mb', format: '%f %% %U').to_i, 1e-5
      assert_raise(ParserError) { parse('16.5 Mb', format: '%f %% %U') }
      assert_raise(ParserError) { parse('16.5 Mb foo', format: '%f %U') }
      assert_raise(ParserError) { parse('16.5 Mb', format: '%f %U foo') }
    end

    def test_parse_predicate
      assert_in_delta 17_301_504, parse?('16.5 Mb').to_i, 1e-5
      assert_nil parse?('16.5 nix', unit: ?b)
    end
  end
end
