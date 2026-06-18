require "minitest/autorun"
require_relative "../lib/bukowski/sk_ast"

class TestSKAst < Minitest::Test
  include Bukowski::SK

  def test_s_combinator
    s = S.new
    assert_equal "S", s.to_s
    assert_equal S.new, s
  end

  def test_k_combinator
    k = K.new
    assert_equal "K", k.to_s
    assert_equal K.new, k
  end

  def test_i_combinator
    i = I.new
    assert_equal "I", i.to_s
    assert_equal I.new, i
  end

  def test_sk_num
    num = SKNum.new(42)
    assert_equal "42", num.to_s
    assert_equal 42, num.value
    assert_equal SKNum.new(42), num
  end

  def test_sk_var
    var = SKVar.new('x')
    assert_equal "x", var.to_s
    assert_equal 'x', var.name
    assert_equal SKVar.new('x'), var
  end

  def test_sk_app_simple
    # I 5
    app = SKApp.new(I.new, SKNum.new(5))
    assert_equal "I 5", app.to_s
  end

  def test_sk_app_nested
    # S K I
    app = SKApp.new(SKApp.new(S.new, K.new), I.new)
    assert_equal "(S K) I", app.to_s
  end

  def test_sk_app_with_parens
    # (S K) (I 5)
    app = SKApp.new(
      SKApp.new(S.new, K.new),
      SKApp.new(I.new, SKNum.new(5))
    )
    assert_equal "(S K) (I 5)", app.to_s
  end

  def test_sk_partial_op
    partial = SKPartialOp.new('+', SKNum.new(2))
    assert_equal "(+ 2 ...)", partial.to_s
    assert_equal '+', partial.op
    assert_equal SKNum.new(2), partial.arg
  end

  def test_equality
    assert_equal S.new, S.new
    assert_equal K.new, K.new
    assert_equal I.new, I.new
    assert_equal SKNum.new(5), SKNum.new(5)
    assert_equal SKVar.new('x'), SKVar.new('x')

    refute_equal S.new, K.new
    refute_equal K.new, I.new
    refute_equal SKNum.new(5), SKNum.new(6)
  end

  def test_sk_lazy_unforced
    lazy = SKLazy.new { SKNum.new(42) }
    refute lazy.forced?
    assert_equal "<lazy>", lazy.to_s
    assert_match(/pending/, lazy.inspect)
  end

  def test_sk_lazy_forced
    lazy = SKLazy.new { SKNum.new(42) }
    result = lazy.force
    assert_equal SKNum.new(42), result
    assert lazy.forced?
    assert_equal "42", lazy.to_s
    assert_match(/forced/, lazy.inspect)
  end

  def test_sk_lazy_memoized
    count = 0
    lazy = SKLazy.new { count += 1; SKNum.new(7) }
    lazy.force
    lazy.force
    lazy.force
    assert_equal 1, count
  end

  def test_sk_lazy_equality
    a = SKLazy.new { SKNum.new(5) }
    b = SKLazy.new { SKNum.new(5) }
    refute_equal a, b
    a.force
    b.force
    assert_equal a, b
  end
end
