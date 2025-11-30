require "minitest/autorun"
require_relative "../lib/bukowski/sk_translator"
require_relative "../lib/bukowski/sk_reducer"

class TestSKTranslator < Minitest::Test
  include Bukowski
  include Bukowski::SK

  def setup
    @translator = Translator.new
    @reducer = Reducer.new
  end

  # Basic translation tests

  def test_translate_variable
    # x → x (as SKVar)
    expr = Var.new('x')
    result = @translator.translate(expr)
    assert_equal SKVar.new('x'), result
  end

  def test_translate_number
    # 42 → 42 (as SKNum)
    expr = Num.new(42)
    result = @translator.translate(expr)
    assert_equal SKNum.new(42), result
  end

  def test_translate_identity
    # \x.x → I
    expr = Abs.new('x', Var.new('x'))
    result = @translator.translate(expr)
    assert_equal I.new, result
  end

  def test_translate_constant_function
    # \x.y → K y
    expr = Abs.new('x', Var.new('y'))
    result = @translator.translate(expr)
    expected = SKApp.new(K.new, SKVar.new('y'))
    assert_equal expected, result
  end

  def test_translate_constant_number
    # \x.5 → K 5
    expr = Abs.new('x', Num.new(5))
    result = @translator.translate(expr)
    expected = SKApp.new(K.new, SKNum.new(5))
    assert_equal expected, result
  end

  def test_translate_k_combinator
    # \x.\y.x → K (semantically, may be S (K K) I)
    expr = Abs.new('x', Abs.new('y', Var.new('x')))
    sk_expr = @translator.translate(expr)
    # Test semantic equivalence: apply to two args and reduce
    test_expr = SKApp.new(SKApp.new(sk_expr, SKVar.new('a')), SKVar.new('b'))
    result = @reducer.reduce(test_expr)
    # Should select first argument (a)
    assert_equal SKVar.new('a'), result
  end

  def test_translate_application
    # (\x.x) y → I y
    expr = App.new(
      Abs.new('x', Var.new('x')),
      Var.new('y')
    )
    result = @translator.translate(expr)
    expected = SKApp.new(I.new, SKVar.new('y'))
    assert_equal expected, result
  end

  def test_translate_simple_application_in_lambda
    # \x.x x → S I I
    expr = Abs.new('x', App.new(Var.new('x'), Var.new('x')))
    result = @translator.translate(expr)
    # T[\x.x x] = S (T[\x.x]) (T[\x.x]) = S I I
    expected = SKApp.new(SKApp.new(S.new, I.new), I.new)
    assert_equal expected, result
  end

  # Translation + Reduction tests (integration)

  def test_translate_and_reduce_identity
    # (\x.x) 5 → I 5 → 5
    expr = App.new(
      Abs.new('x', Var.new('x')),
      Num.new(5)
    )
    sk_expr = @translator.translate(expr)
    result = @reducer.reduce(sk_expr)
    assert_equal SKNum.new(5), result
  end

  def test_translate_and_reduce_k_combinator
    # (\x.\y.x) a b → K a b → a
    expr = App.new(
      App.new(
        Abs.new('x', Abs.new('y', Var.new('x'))),
        Var.new('a')
      ),
      Var.new('b')
    )
    sk_expr = @translator.translate(expr)
    result = @reducer.reduce(sk_expr)
    assert_equal SKVar.new('a'), result
  end

  def test_translate_and_reduce_application
    # (\x.x x) (\y.y) → (S I I) I → I I (I I) → I (I I) → I I → I
    # Wait, let me recalculate:
    # \x.x x translates to S I I
    # (S I I) I reduces: S I I I = I I (I I) = I (I I) = I I = I... hmm
    # Actually: I I (I I) = I (I I) = I I = I
    # Let's use a simpler test
    expr = App.new(
      Abs.new('x', Var.new('x')),
      Abs.new('y', Var.new('y'))
    )
    sk_expr = @translator.translate(expr)
    # (\x.x) (\y.y) → I I → I
    result = @reducer.reduce(sk_expr)
    assert_equal I.new, result
  end

  def test_translate_and_reduce_arithmetic
    # (\x.+ x 3) 2 → ... → 5
    expr = App.new(
      Abs.new('x', App.new(
        App.new(Var.new('+'), Var.new('x')),
        Num.new(3)
      )),
      Num.new(2)
    )
    sk_expr = @translator.translate(expr)
    result = @reducer.reduce(sk_expr)
    assert_equal SKNum.new(5), result
  end

  def test_translate_church_true
    # \t.\f.t → K (semantically, may be S (K K) I)
    expr = Abs.new('t', Abs.new('f', Var.new('t')))
    sk_expr = @translator.translate(expr)
    # Test semantic equivalence: apply to two args
    test_expr = SKApp.new(SKApp.new(sk_expr, SKVar.new('a')), SKVar.new('b'))
    result = @reducer.reduce(test_expr)
    # Should select first argument (true behavior)
    assert_equal SKVar.new('a'), result
  end

  def test_translate_church_false
    # \t.\f.f → K I
    expr = Abs.new('t', Abs.new('f', Var.new('f')))
    result = @translator.translate(expr)
    # Should be K I
    assert_equal SKApp.new(K.new, I.new), result
  end

  def test_translate_and_reduce_church_boolean_selection
    # (\t.\f.t) a b → K a b → a
    true_func = Abs.new('t', Abs.new('f', Var.new('t')))
    expr = App.new(
      App.new(true_func, Var.new('a')),
      Var.new('b')
    )
    sk_expr = @translator.translate(expr)
    result = @reducer.reduce(sk_expr)
    assert_equal SKVar.new('a'), result
  end

  def test_translate_nested_lambda
    # \x.\y.y → K I
    expr = Abs.new('x', Abs.new('y', Var.new('y')))
    result = @translator.translate(expr)
    # x doesn't appear in \y.y, so K (T[\y.y])
    # T[\y.y] = I
    # So K I
    assert_equal SKApp.new(K.new, I.new), result
  end

  def test_translate_complex_expression
    # (\x.\y.+ x y) 2 3 → 5
    lambda_expr = Abs.new('x',
      Abs.new('y',
        App.new(
          App.new(Var.new('+'), Var.new('x')),
          Var.new('y')
        )
      )
    )
    expr = App.new(
      App.new(lambda_expr, Num.new(2)),
      Num.new(3)
    )
    sk_expr = @translator.translate(expr)
    result = @reducer.reduce(sk_expr)
    assert_equal SKNum.new(5), result
  end
end
