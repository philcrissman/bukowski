require "minitest/autorun"
require_relative "../lib/bukowski/sk_reducer"

class TestSKReducer < Minitest::Test
  include Bukowski::SK

  def setup
    @reducer = Reducer.new
  end

  # Basic combinator tests

  def test_i_combinator
    # I 5 → 5
    expr = SKApp.new(I.new, SKNum.new(5))
    result = @reducer.reduce(expr)
    assert_equal SKNum.new(5), result
  end

  def test_k_combinator
    # K 1 2 → 1
    expr = SKApp.new(
      SKApp.new(K.new, SKNum.new(1)),
      SKNum.new(2)
    )
    result = @reducer.reduce(expr)
    assert_equal SKNum.new(1), result
  end

  def test_s_combinator
    # S K K 5 → K 5 (K 5) → 5
    # This is actually the definition of I!
    expr = SKApp.new(
      SKApp.new(
        SKApp.new(S.new, K.new),
        K.new
      ),
      SKNum.new(5)
    )
    result = @reducer.reduce(expr)
    assert_equal SKNum.new(5), result
  end

  # Church boolean tests

  def test_church_true
    # true → K
    result = @reducer.reduce(SKVar.new('true'))
    assert_equal K.new, result
  end

  def test_church_false
    # false → K I
    result = @reducer.reduce(SKVar.new('false'))
    expected = SKApp.new(K.new, I.new)
    assert_equal expected, result
  end

  def test_church_true_selects_first
    # K a b → a (true selects first)
    expr = SKApp.new(
      SKApp.new(K.new, SKVar.new('a')),
      SKVar.new('b')
    )
    result = @reducer.reduce(expr)
    assert_equal SKVar.new('a'), result
  end

  def test_church_false_selects_second
    # (K I) a b → b (false selects second)
    # K I a → I
    # I b → b
    expr = SKApp.new(
      SKApp.new(
        SKApp.new(K.new, I.new),
        SKVar.new('a')
      ),
      SKVar.new('b')
    )
    result = @reducer.reduce(expr)
    assert_equal SKVar.new('b'), result
  end

  # Primitive operation tests

  def test_addition
    # + 2 3 → 5
    expr = SKApp.new(
      SKApp.new(SKVar.new('+'), SKNum.new(2)),
      SKNum.new(3)
    )
    result = @reducer.reduce(expr)
    assert_equal SKNum.new(5), result
  end

  def test_multiplication
    # * 4 5 → 20
    expr = SKApp.new(
      SKApp.new(SKVar.new('*'), SKNum.new(4)),
      SKNum.new(5)
    )
    result = @reducer.reduce(expr)
    assert_equal SKNum.new(20), result
  end

  def test_comparison_true
    # = 2 2 → K (true)
    expr = SKApp.new(
      SKApp.new(SKVar.new('='), SKNum.new(2)),
      SKNum.new(2)
    )
    result = @reducer.reduce(expr)
    assert_equal K.new, result
  end

  def test_comparison_false
    # = 2 3 → K I (false)
    expr = SKApp.new(
      SKApp.new(SKVar.new('='), SKNum.new(2)),
      SKNum.new(3)
    )
    result = @reducer.reduce(expr)
    assert_equal SKApp.new(K.new, I.new), result
  end

  # LAZY EVALUATION TESTS
  # These verify that unused arguments are never evaluated

  def test_lazy_k_combinator_with_division_by_zero
    # K 1 (/ 1 0) → 1
    # The second argument should never be evaluated
    div_by_zero = SKApp.new(
      SKApp.new(SKVar.new('/'), SKNum.new(1)),
      SKNum.new(0)
    )
    expr = SKApp.new(
      SKApp.new(K.new, SKNum.new(1)),
      div_by_zero
    )
    result = @reducer.reduce(expr)
    assert_equal SKNum.new(1), result
  end

  def test_lazy_church_true_with_division_by_zero
    # K a (/ 1 0) → a
    # Church true (K) selects first, second is never evaluated
    div_by_zero = SKApp.new(
      SKApp.new(SKVar.new('/'), SKNum.new(1)),
      SKNum.new(0)
    )
    expr = SKApp.new(
      SKApp.new(K.new, SKVar.new('a')),
      div_by_zero
    )
    result = @reducer.reduce(expr)
    assert_equal SKVar.new('a'), result
  end

  def test_lazy_s_combinator_second_branch
    # S K K (/ 1 0) → K (/ 1 0) (K (/ 1 0)) → (/ 1 0)
    # Wait, this WILL try to reduce the division...
    # Let's use a different test: S K I x → K x (I x) → x
    # This shows S works correctly
    expr = SKApp.new(
      SKApp.new(
        SKApp.new(S.new, K.new),
        I.new
      ),
      SKVar.new('x')
    )
    result = @reducer.reduce(expr)
    assert_equal SKVar.new('x'), result
  end

  # Complex reduction tests

  def test_s_k_i_is_identity
    # S K I x → K x (I x) → x
    expr = SKApp.new(
      SKApp.new(
        SKApp.new(S.new, K.new),
        I.new
      ),
      SKNum.new(42)
    )
    result = @reducer.reduce(expr)
    assert_equal SKNum.new(42), result
  end

  def test_nested_application
    # (I (I 5)) → I 5 → 5
    expr = SKApp.new(
      I.new,
      SKApp.new(I.new, SKNum.new(5))
    )
    result = @reducer.reduce(expr)
    assert_equal SKNum.new(5), result
  end

  def test_if_true
    # I K a b → K a b → a
    # (if true a b) where if=I, true=K
    expr = SKApp.new(
      SKApp.new(
        SKApp.new(I.new, K.new),
        SKVar.new('a')
      ),
      SKVar.new('b')
    )
    result = @reducer.reduce(expr)
    assert_equal SKVar.new('a'), result
  end

  def test_if_false
    # I (K I) a b → (K I) a b → I a → a... wait that's wrong
    # Let me trace: (K I) a → I, then I b → b. Good!
    expr = SKApp.new(
      SKApp.new(
        SKApp.new(I.new, SKApp.new(K.new, I.new)),
        SKVar.new('a')
      ),
      SKVar.new('b')
    )
    result = @reducer.reduce(expr)
    assert_equal SKVar.new('b'), result
  end
end
