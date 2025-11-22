require "minitest/autorun"
require_relative "../lib/bukowski/parser"

class TestParser < Minitest::Test
  include Bukowski

  def test_simple_valid_expression
    tokens = [
      Token.new(:LAM),
      Token.new(:VAR, 'x'),
      Token.new(:DOT),
      Token.new(:VAR, 'x'),
      Token.new(:EOF)
    ]
    ast = Parser.new(tokens).parse

    assert_equal Abs.new('x', Var.new('x')), ast
  end

  def test_another_expression
    tokens = [
      Token.new(:LPAREN),
      Token.new(:LAM),
      Token.new(:VAR, 'x'),
      Token.new(:DOT),
      Token.new(:LAM),
      Token.new(:VAR, 'y'),
      Token.new(:DOT),
      Token.new(:VAR, 'x'),
      Token.new(:RPAREN),
      Token.new(:VAR, 'a'),
      Token.new(:VAR, 'b'),
      Token.new(:EOF)
    ]

    ast = Parser.new(tokens).parse
    expected = 
      App.new(
        App.new(
          Abs.new('x',
                  Abs.new('y', Var.new('x'))),
        Var.new('a')),
        Var.new('b'))

    assert_equal expected, ast
  end
end
