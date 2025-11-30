require "minitest/autorun"
require_relative "../lib/bukowski/evaluator"
require_relative "../lib/bukowski/sk_translator"
require_relative "../lib/bukowski/sk_reducer"

class TestIntegration < Minitest::Test
  include Bukowski
  include Bukowski::SK

  def setup
    @lc_evaluator = Evaluator.new
    @sk_translator = Translator.new
    @sk_reducer = Reducer.new
  end

  # Helper to convert SK result back to LC for comparison
  def sk_to_comparable(sk_expr)
    case sk_expr
    when SKNum
      sk_expr.value
    when SKVar
      sk_expr.name
    when K
      :church_true
    when SKApp
      if sk_expr.func.is_a?(K) && sk_expr.arg.is_a?(I)
        :church_false
      else
        sk_expr
      end
    when I
      :identity
    else
      sk_expr
    end
  end

  def lc_to_comparable(lc_expr)
    case lc_expr
    when Num
      lc_expr.value
    when Var
      lc_expr.name
    when Abs
      # Check if it's a Church boolean
      if lc_expr.param == 't' &&
         lc_expr.body.is_a?(Abs) &&
         lc_expr.body.param == 'f' &&
         lc_expr.body.body.is_a?(Var)
        if lc_expr.body.body.name == 't'
          :church_true
        elsif lc_expr.body.body.name == 'f'
          :church_false
        else
          lc_expr
        end
      elsif lc_expr.param == 'x' && lc_expr.body.is_a?(Var) && lc_expr.body.name == 'x'
        :identity
      else
        lc_expr
      end
    else
      lc_expr
    end
  end

  # Test: Identity function
  def test_identity_both_paths
    # (\x.x) 5 → 5
    expr = App.new(
      Abs.new('x', Var.new('x')),
      Num.new(5)
    )

    # LC path
    lc_result = @lc_evaluator.evaluate(expr)

    # SK path
    sk_expr = @sk_translator.translate(expr)
    sk_result = @sk_reducer.reduce(sk_expr)

    assert_equal 5, lc_to_comparable(lc_result)
    assert_equal 5, sk_to_comparable(sk_result)
  end

  # Test: K combinator
  def test_k_combinator_both_paths
    # (\x.\y.x) a b → a
    expr = App.new(
      App.new(
        Abs.new('x', Abs.new('y', Var.new('x'))),
        Var.new('a')
      ),
      Var.new('b')
    )

    # LC path
    lc_result = @lc_evaluator.evaluate(expr)

    # SK path
    sk_expr = @sk_translator.translate(expr)
    sk_result = @sk_reducer.reduce(sk_expr)

    assert_equal 'a', lc_to_comparable(lc_result)
    assert_equal 'a', sk_to_comparable(sk_result)
  end

  # Test: Arithmetic
  def test_arithmetic_both_paths
    # + 2 3 → 5
    expr = App.new(
      App.new(Var.new('+'), Num.new(2)),
      Num.new(3)
    )

    # LC path
    lc_result = @lc_evaluator.evaluate(expr)

    # SK path
    sk_expr = @sk_translator.translate(expr)
    sk_result = @sk_reducer.reduce(sk_expr)

    assert_equal 5, lc_to_comparable(lc_result)
    assert_equal 5, sk_to_comparable(sk_result)
  end

  # Test: Lambda with arithmetic
  def test_lambda_arithmetic_both_paths
    # (\x.+ x 3) 2 → 5
    expr = App.new(
      Abs.new('x', App.new(
        App.new(Var.new('+'), Var.new('x')),
        Num.new(3)
      )),
      Num.new(2)
    )

    # LC path
    lc_result = @lc_evaluator.evaluate(expr)

    # SK path
    sk_expr = @sk_translator.translate(expr)
    sk_result = @sk_reducer.reduce(sk_expr)

    assert_equal 5, lc_to_comparable(lc_result)
    assert_equal 5, sk_to_comparable(sk_result)
  end

  # Test: Church boolean true
  def test_church_true_both_paths
    # (\t.\f.t) a b → a
    expr = App.new(
      App.new(
        Abs.new('t', Abs.new('f', Var.new('t'))),
        Var.new('a')
      ),
      Var.new('b')
    )

    # LC path
    lc_result = @lc_evaluator.evaluate(expr)

    # SK path
    sk_expr = @sk_translator.translate(expr)
    sk_result = @sk_reducer.reduce(sk_expr)

    assert_equal 'a', lc_to_comparable(lc_result)
    assert_equal 'a', sk_to_comparable(sk_result)
  end

  # Test: Church boolean false
  def test_church_false_both_paths
    # (\t.\f.f) a b → b
    expr = App.new(
      App.new(
        Abs.new('t', Abs.new('f', Var.new('f'))),
        Var.new('a')
      ),
      Var.new('b')
    )

    # LC path
    lc_result = @lc_evaluator.evaluate(expr)

    # SK path
    sk_expr = @sk_translator.translate(expr)
    sk_result = @sk_reducer.reduce(sk_expr)

    assert_equal 'b', lc_to_comparable(lc_result)
    assert_equal 'b', sk_to_comparable(sk_result)
  end

  # Test: Comparison returning Church boolean
  def test_comparison_both_paths
    # = 2 2 → true (Church boolean)
    expr = App.new(
      App.new(Var.new('='), Num.new(2)),
      Num.new(2)
    )

    # LC path
    lc_result = @lc_evaluator.evaluate(expr)

    # SK path
    sk_expr = @sk_translator.translate(expr)
    sk_result = @sk_reducer.reduce(sk_expr)

    assert_equal :church_true, lc_to_comparable(lc_result)
    assert_equal :church_true, sk_to_comparable(sk_result)
  end

  # Test: If with true condition
  def test_if_true_both_paths
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

    # LC path
    lc_result = @lc_evaluator.evaluate(expr)

    # SK path
    sk_expr = @sk_translator.translate(expr)
    sk_result = @sk_reducer.reduce(sk_expr)

    assert_equal 10, lc_to_comparable(lc_result)
    assert_equal 10, sk_to_comparable(sk_result)
  end

  # Test: If with false condition
  def test_if_false_both_paths
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

    # LC path
    lc_result = @lc_evaluator.evaluate(expr)

    # SK path
    sk_expr = @sk_translator.translate(expr)
    sk_result = @sk_reducer.reduce(sk_expr)

    assert_equal 20, lc_to_comparable(lc_result)
    assert_equal 20, sk_to_comparable(sk_result)
  end

  # Test: Nested lambda
  def test_nested_lambda_both_paths
    # (\x.\y.+ x y) 2 3 → 5
    expr = App.new(
      App.new(
        Abs.new('x', Abs.new('y',
          App.new(App.new(Var.new('+'), Var.new('x')), Var.new('y'))
        )),
        Num.new(2)
      ),
      Num.new(3)
    )

    # LC path
    lc_result = @lc_evaluator.evaluate(expr)

    # SK path
    sk_expr = @sk_translator.translate(expr)
    sk_result = @sk_reducer.reduce(sk_expr)

    assert_equal 5, lc_to_comparable(lc_result)
    assert_equal 5, sk_to_comparable(sk_result)
  end
end
