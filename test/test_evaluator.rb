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

  def test_simple_addition
    # + 2 3 → 5
    expr = App.new(
      App.new(Var.new('+'), Num.new(2)),
      Num.new(3)
    )
    result = Evaluator.new.evaluate(expr)
    assert_equal Num.new(5), result
  end

  def test_church_true
    # true → λt.λf.t
    expr = Var.new('true')
    result = Evaluator.new.evaluate(expr)
    expected = Abs.new('t', Abs.new('f', Var.new('t')))
    assert_equal expected, result
    assert_equal :true, Evaluator.church_boolean?(result)
  end

  def test_church_false
    # false → λt.λf.f
    expr = Var.new('false')
    result = Evaluator.new.evaluate(expr)
    expected = Abs.new('t', Abs.new('f', Var.new('f')))
    assert_equal expected, result
    assert_equal :false, Evaluator.church_boolean?(result)
  end

  def test_if_true_returns_first_arg
    # if true a b → a
    # This is actually: ((if true) a) b
    # Since if is identity: (true a) b
    # And true is λt.λf.t, so (true a) → λf.a
    # Then (λf.a) b → a
    expr = App.new(
      App.new(
        App.new(Var.new('if'), Var.new('true')),
        Var.new('a')
      ),
      Var.new('b')
    )
    result = Evaluator.new.evaluate(expr)
    assert_equal Var.new('a'), result
  end

  def test_if_false_returns_second_arg
    # if false a b → b
    expr = App.new(
      App.new(
        App.new(Var.new('if'), Var.new('false')),
        Var.new('a')
      ),
      Var.new('b')
    )
    result = Evaluator.new.evaluate(expr)
    assert_equal Var.new('b'), result
  end

  def test_comparison_returns_church_boolean
    # = 2 2 → true (as Church boolean)
    expr = App.new(
      App.new(Var.new('='), Num.new(2)),
      Num.new(2)
    )
    result = Evaluator.new.evaluate(expr)
    assert_equal :true, Evaluator.church_boolean?(result)
  end

  def test_comparison_false_returns_church_boolean
    # = 2 3 → false (as Church boolean)
    expr = App.new(
      App.new(Var.new('='), Num.new(2)),
      Num.new(3)
    )
    result = Evaluator.new.evaluate(expr)
    assert_equal :false, Evaluator.church_boolean?(result)
  end

  def test_if_with_comparison
    # if (= 2 2) 10 20 → 10
    cond = App.new(
      App.new(Var.new('='), Num.new(2)),
      Num.new(2)
    )
    expr = App.new(
      App.new(
        App.new(Var.new('if'), cond),
        Num.new(10)
      ),
      Num.new(20)
    )
    result = Evaluator.new.evaluate(expr)
    assert_equal Num.new(10), result
  end

  def test_if_with_false_comparison
    # if (= 2 3) 10 20 → 20
    cond = App.new(
      App.new(Var.new('='), Num.new(2)),
      Num.new(3)
    )
    expr = App.new(
      App.new(
        App.new(Var.new('if'), cond),
        Num.new(10)
      ),
      Num.new(20)
    )
    result = Evaluator.new.evaluate(expr)
    assert_equal Num.new(20), result
  end

  # LAZY EVALUATION TESTS
  # These tests verify that unused arguments are never evaluated

  def test_lazy_k_combinator_with_division_by_zero
    # (\x.\y.x) 1 (/ 1 0) → 1
    # The second argument (division by zero) should never be evaluated
    # because the K combinator returns the first argument
    k = Abs.new('x', Abs.new('y', Var.new('x')))
    div_by_zero = App.new(
      App.new(Var.new('/'), Num.new(1)),
      Num.new(0)
    )
    expr = App.new(
      App.new(k, Num.new(1)),
      div_by_zero
    )
    result = Evaluator.new.evaluate(expr)
    assert_equal Num.new(1), result
  end

  def test_lazy_true_with_division_by_zero
    # true 1 (/ 1 0) → 1
    # Church true selects first argument, second should never be evaluated
    div_by_zero = App.new(
      App.new(Var.new('/'), Num.new(1)),
      Num.new(0)
    )
    expr = App.new(
      App.new(Var.new('true'), Num.new(1)),
      div_by_zero
    )
    result = Evaluator.new.evaluate(expr)
    assert_equal Num.new(1), result
  end

  def test_lazy_if_true_unused_branch_not_evaluated
    # if true 1 (/ 1 0) → 1
    # The false branch (division by zero) should never be evaluated
    div_by_zero = App.new(
      App.new(Var.new('/'), Num.new(1)),
      Num.new(0)
    )
    expr = App.new(
      App.new(
        App.new(Var.new('if'), Var.new('true')),
        Num.new(1)
      ),
      div_by_zero
    )
    result = Evaluator.new.evaluate(expr)
    assert_equal Num.new(1), result
  end

  def test_lazy_if_false_unused_branch_not_evaluated
    # if false (/ 1 0) 2 → 2
    # The true branch (division by zero) should never be evaluated
    div_by_zero = App.new(
      App.new(Var.new('/'), Num.new(1)),
      Num.new(0)
    )
    expr = App.new(
      App.new(
        App.new(Var.new('if'), Var.new('false')),
        div_by_zero
      ),
      Num.new(2)
    )
    result = Evaluator.new.evaluate(expr)
    assert_equal Num.new(2), result
  end
end
