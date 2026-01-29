require "minitest/autorun"
require_relative "../lib/bukowski/tokenizer"
require_relative "../lib/bukowski/parser"
require_relative "../lib/bukowski/sk_translator"
require_relative "../lib/bukowski/sk_reducer"

class TestIntegration < Minitest::Test
  include Bukowski
  include Bukowski::SK

  def setup
    @sk_translator = Translator.new
    @sk_reducer = Reducer.new
  end

  # Helper to convert SK result to comparable value
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

  def evaluate(expr)
    sk_expr = @sk_translator.translate(expr)
    @sk_reducer.reduce(sk_expr)
  end

  def evaluate_source(source)
    tokens = Tokenizer.new(source).tokenize
    ast = Parser.new(tokens).parse
    evaluate(ast)
  end

  # Test: Identity function
  def test_identity
    # (\x.x) 5 → 5
    expr = App.new(
      Abs.new('x', Var.new('x')),
      Num.new(5)
    )

    result = evaluate(expr)
    assert_equal 5, sk_to_comparable(result)
  end

  # Test: K combinator
  def test_k_combinator
    # (\x.\y.x) a b → a
    expr = App.new(
      App.new(
        Abs.new('x', Abs.new('y', Var.new('x'))),
        Var.new('a')
      ),
      Var.new('b')
    )

    result = evaluate(expr)
    assert_equal 'a', sk_to_comparable(result)
  end

  # Test: Arithmetic
  def test_arithmetic
    # + 2 3 → 5
    expr = App.new(
      App.new(Var.new('+'), Num.new(2)),
      Num.new(3)
    )

    result = evaluate(expr)
    assert_equal 5, sk_to_comparable(result)
  end

  # Test: Lambda with arithmetic
  def test_lambda_arithmetic
    # (\x.+ x 3) 2 → 5
    expr = App.new(
      Abs.new('x', App.new(
        App.new(Var.new('+'), Var.new('x')),
        Num.new(3)
      )),
      Num.new(2)
    )

    result = evaluate(expr)
    assert_equal 5, sk_to_comparable(result)
  end

  # Test: Church boolean true
  def test_church_true
    # (\t.\f.t) a b → a
    expr = App.new(
      App.new(
        Abs.new('t', Abs.new('f', Var.new('t'))),
        Var.new('a')
      ),
      Var.new('b')
    )

    result = evaluate(expr)
    assert_equal 'a', sk_to_comparable(result)
  end

  # Test: Church boolean false
  def test_church_false
    # (\t.\f.f) a b → b
    expr = App.new(
      App.new(
        Abs.new('t', Abs.new('f', Var.new('f'))),
        Var.new('a')
      ),
      Var.new('b')
    )

    result = evaluate(expr)
    assert_equal 'b', sk_to_comparable(result)
  end

  # Test: Comparison returning Church boolean
  def test_comparison
    # = 2 2 → true (Church boolean)
    expr = App.new(
      App.new(Var.new('='), Num.new(2)),
      Num.new(2)
    )

    result = evaluate(expr)
    assert_equal :church_true, sk_to_comparable(result)
  end

  # Test: If with true condition
  def test_if_true
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

    result = evaluate(expr)
    assert_equal 10, sk_to_comparable(result)
  end

  # Test: If with false condition
  def test_if_false
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

    result = evaluate(expr)
    assert_equal 20, sk_to_comparable(result)
  end

  # Test: Nested lambda
  def test_nested_lambda
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

    result = evaluate(expr)
    assert_equal 5, sk_to_comparable(result)
  end

  # LIST INTEGRATION TESTS

  def test_list_literal
    # {1 2 3} → SKCons(1, SKCons(2, SKCons(3, SKNil)))
    result = evaluate_source("{1 2 3}")
    expected = SKCons.new(SKNum.new(1), SKCons.new(SKNum.new(2), SKCons.new(SKNum.new(3), SKNil.new)))
    assert_equal expected, result
  end

  def test_empty_list
    # {} → SKNil
    result = evaluate_source("{}")
    assert_equal SKNil.new, result
  end

  def test_head_of_list
    # head {1 2 3} → 1
    result = evaluate_source("head {1 2 3}")
    assert_equal SKNum.new(1), result
  end

  def test_tail_of_list
    # tail {1 2 3} → {2 3}
    result = evaluate_source("tail {1 2 3}")
    expected = SKCons.new(SKNum.new(2), SKCons.new(SKNum.new(3), SKNil.new))
    assert_equal expected, result
  end

  def test_cons_onto_list
    # cons 0 {1 2 3} → {0 1 2 3}
    result = evaluate_source("cons 0 {1 2 3}")
    expected = SKCons.new(SKNum.new(0), SKCons.new(SKNum.new(1), SKCons.new(SKNum.new(2), SKCons.new(SKNum.new(3), SKNil.new))))
    assert_equal expected, result
  end

  def test_isnil_empty
    # isnil {} → true
    result = evaluate_source("isnil {}")
    assert_equal :church_true, sk_to_comparable(result)
  end

  def test_isnil_nonempty
    # isnil {1} → false
    result = evaluate_source("isnil {1}")
    assert_equal :church_false, sk_to_comparable(result)
  end

  def test_list_to_s
    # Verify pretty-printing
    result = evaluate_source("{1 2 3}")
    assert_equal "{1 2 3}", result.to_s
  end

  # MAP / FOLD / Y INTEGRATION TESTS

  def test_map_source
    # map (\x.* x 2) {1 2 3} → {2 4 6}
    result = evaluate_source('map (\x.* x 2) {1 2 3}')
    assert_equal "{2 4 6}", result.to_s
  end

  def test_map_empty_source
    # map (\x.* x 2) {} → {}
    result = evaluate_source('map (\x.* x 2) {}')
    assert_equal SKNil.new, result
  end

  def test_fold_source
    # fold (\x.\y.+ x y) 0 {1 2 3} → 6
    result = evaluate_source('fold (\x.\y.+ x y) 0 {1 2 3}')
    assert_equal SKNum.new(6), result
  end

  def test_fold_empty_source
    # fold (\x.\y.+ x y) 0 {} → 0
    result = evaluate_source('fold (\x.\y.+ x y) 0 {}')
    assert_equal SKNum.new(0), result
  end

  def test_y_recursive
    # Sum 1..3 using Y combinator
    source = 'let sum = Y (\self.\n.if (= n 0) 0 (+ n (self (- n 1)))) in sum 3'
    result = evaluate_source(source)
    assert_equal SKNum.new(6), result
  end

  def test_y_with_list
    # Double each element using Y
    source = 'let double = Y (\self.\lst.if (isnil lst) {} (cons (* 2 (head lst)) (self (tail lst)))) in double {1 2 3}'
    result = evaluate_source(source)
    assert_equal "{2 4 6}", result.to_s
  end
end
