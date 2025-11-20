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
end
