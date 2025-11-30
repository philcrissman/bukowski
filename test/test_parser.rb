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

  def test_expression_of_operation_on_integers
    tokens = [
      Token.new(:OP, '+'),
      Token.new(:NUM, 2),
      Token.new(:NUM, 3),
      Token.new(:EOF)
    ]

    ast = Parser.new(tokens).parse
    expected = App.new(
      App.new(Var.new('+'), Num.new(2)),
      Num.new(3)
    )

    assert_equal expected, ast
  end

  def test_parse_true
    tokens = [
      Token.new(:TRUE),
      Token.new(:EOF)
    ]

    ast = Parser.new(tokens).parse
    assert_equal Var.new('true'), ast
  end

  def test_parse_false
    tokens = [
      Token.new(:FALSE),
      Token.new(:EOF)
    ]

    ast = Parser.new(tokens).parse
    assert_equal Var.new('false'), ast
  end

  def test_parse_if_expression
    # if true a b -> ((if true) a) b
    tokens = [
      Token.new(:IF),
      Token.new(:TRUE),
      Token.new(:VAR, 'a'),
      Token.new(:VAR, 'b'),
      Token.new(:EOF)
    ]

    ast = Parser.new(tokens).parse
    expected = App.new(
      App.new(
        App.new(Var.new('if'), Var.new('true')),
        Var.new('a')
      ),
      Var.new('b')
    )

    assert_equal expected, ast
  end

  def test_parse_if_with_comparison
    # if (= 2 3) a b
    tokens = [
      Token.new(:IF),
      Token.new(:LPAREN),
      Token.new(:OP, '='),
      Token.new(:NUM, 2),
      Token.new(:NUM, 3),
      Token.new(:RPAREN),
      Token.new(:VAR, 'a'),
      Token.new(:VAR, 'b'),
      Token.new(:EOF)
    ]

    ast = Parser.new(tokens).parse
    expected = App.new(
      App.new(
        App.new(
          Var.new('if'),
          App.new(
            App.new(Var.new('='), Num.new(2)),
            Num.new(3)
          )
        ),
        Var.new('a')
      ),
      Var.new('b')
    )

    assert_equal expected, ast
  end
end
