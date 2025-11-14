# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/bukowski/tokenizer"

class TestTokenizer < Minitest::Test
  include Bukowski

  def test_simple_lambda
    input = "\\x. x + 1"
    t = Tokenizer.new(input).tokenize.map(&:to_s)
    assert_equal(
      %w[LAM IDENT("x") DOT IDENT("x") IDENT("+") INT(1) EOF],
      t
    )
  end

  def test_string
    input = '"hello, world"'
    t = Tokenizer.new(input).tokenize.map(&:to_s)
    assert_equal(
      ["STRING(\"hello, world\")", "EOF"],
      t
    )
  end

  def test_string_with_newlines_and_tabs_and_quotes
    input = '"\thello, \n\"world\""'
    t = Tokenizer.new(input).tokenize.map(&:to_s)
    assert_equal(
      ["STRING(\"\\thello, \\n\\\"world\\\"\")", "EOF"],
      t
    )
  end
end

