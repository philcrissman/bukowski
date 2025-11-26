# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/bukowski/tokenizer"

class TestTokenizer < Minitest::Test
  include Bukowski

  def test_simple_lambda
    input = "\\x.x"
    tokens = Tokenizer.new(input).tokenize.map(&:to_s)
    assert_equal(
      %w[LAM VAR(x) DOT VAR(x) EOF],
      tokens
    )
  end

  def test_another_lambda
    input = '\x.\y.x'
    tokens = Tokenizer.new(input).tokenize.map(&:to_s)
    assert_equal(
      %w[LAM VAR(x) DOT LAM VAR(y) DOT VAR(x) EOF],
      tokens
    )
  end

  def test_expression_with_parens
    input = '(\x.\y.(y)x)b'
    tokens = Tokenizer.new(input).tokenize.map(&:to_s)
    assert_equal(
      %w[LPAREN LAM VAR(x) DOT LAM VAR(y) DOT LPAREN VAR(y) RPAREN VAR(x) RPAREN VAR(b) EOF],
      tokens
    )
  end

  def test_integers 
    input = '42'
    tokens = Tokenizer.new(input).tokenize.map(&:to_s)
    assert_equal(
      %w[NUM(42) EOF],
      tokens
    )
  end

  def test_reserved_words
    input = 'if true x y'
    tokens = Tokenizer.new(input).tokenize.map(&:to_s)
    assert_equal(
      %w[IF TRUE VAR(x) VAR(y) EOF],
      tokens
    )
  end

  def test_operations
    input = '(+ 3 2)'
    tokens = Tokenizer.new(input).tokenize.map(&:to_s)
    assert_equal(
      %w[LPAREN OP(+) NUM(3) NUM(2) RPAREN EOF],
      tokens
    )
  end
end

