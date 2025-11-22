require "minitest/autorun"
require_relative "../lib/bukowski/evaluator"

class TestEvaluator < Minitest::Test
  include Bukowski

  def test_identity_function
    # (\x.x) a → a
    expr = App.new(
      Abs.new('x', Var.new('x')),
      Var.new('a')
    )
    evaluator = Evaluator.new
    result = evaluator.evaluate(expr)
    assert_equal Var.new('a'), result
  end

  def test_constant_function
    # (\x.\y.x) a b → a
    k = Abs.new('x', Abs.new('y', Var.new('x')))
    expr = App.new(App.new(k, Var.new('a')), Var.new('b'))
    result = Evaluator.new.evaluate(expr)
    assert_equal Var.new('a'), result
  end

  def test_free_variable
    # x → x (can't reduce)
    expr = Var.new('x')
    result = Evaluator.new.evaluate(expr)
    assert_equal Var.new('x'), result
  end

  def test_lambda_is_a_value
    # \x.x → \x.x (lambdas don't reduce)
    expr = Abs.new('x', Var.new('x'))
    result = Evaluator.new.evaluate(expr)
    assert_equal Abs.new('x', Var.new('x')), result
  end

end
