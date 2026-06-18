# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/bukowski/evaluator"

class TestEvaluator < Minitest::Test
  include Bukowski::Val

  def setup
    @eval = Bukowski::Evaluator.new
  end

  def ev(source)
    @eval.evaluate_source(source)
  end

  # ARITHMETIC

  def test_addition
    assert_equal VNum.new(5), ev('+ 2 3')
  end

  def test_subtraction
    assert_equal VNum.new(1), ev('- 3 2')
  end

  def test_multiplication
    assert_equal VNum.new(12), ev('* 3 4')
  end

  def test_division
    assert_equal VNum.new(3), ev('/ 9 3')
  end

  def test_modulo
    assert_equal VNum.new(1), ev('% 7 3')
  end

  def test_float
    assert_equal VNum.new(2.5), ev('/ 5.0 2.0')
  end

  def test_nested_arithmetic
    assert_equal VNum.new(11), ev('+ 2 (* 3 3)')
  end

  # BOOLEANS AND COMPARISON

  def test_true
    assert_equal VBool.new(true), ev('true')
  end

  def test_false
    assert_equal VBool.new(false), ev('false')
  end

  def test_equality_true
    assert_equal VBool.new(true), ev('= 2 2')
  end

  def test_equality_false
    assert_equal VBool.new(false), ev('= 2 3')
  end

  def test_less_than_true
    assert_equal VBool.new(true), ev('< 2 3')
  end

  def test_less_than_false
    assert_equal VBool.new(false), ev('< 3 2')
  end

  def test_greater_than
    assert_equal VBool.new(true), ev('> 5 3')
  end

  def test_cross_type_equality
    assert_equal VBool.new(false), ev('= 42 "42"')
  end

  # IF

  def test_if_true
    assert_equal VNum.new(1), ev('if true 1 0')
  end

  def test_if_false
    assert_equal VNum.new(0), ev('if false 1 0')
  end

  def test_if_with_comparison
    assert_equal VNum.new(10), ev('if (= 2 2) 10 20')
  end

  def test_if_false_comparison
    assert_equal VNum.new(20), ev('if (= 2 3) 10 20')
  end

  # LAMBDA AND APPLICATION

  def test_identity
    assert_equal VNum.new(5), ev('(\x.x) 5')
  end

  def test_constant
    assert_equal VNum.new(3), ev('(\x.3) 99')
  end

  def test_lambda_arithmetic
    assert_equal VNum.new(7), ev('(\x.+ x 2) 5')
  end

  def test_nested_lambda
    assert_equal VNum.new(5), ev('(\x.\y.+ x y) 2 3')
  end

  # CLOSURES

  def test_closure_captures_env
    assert_equal VNum.new(10), ev('let add = \x.\y.+ x y in add 3 7')
  end

  def test_closure_partial_application
    result = ev('let add = \x.\y.+ x y in let inc = add 1 in inc 5')
    assert_equal VNum.new(6), result
  end

  def test_closure_captures_outer_variable
    result = ev('let x = 10 in let f = \y.+ x y in f 5')
    assert_equal VNum.new(15), result
  end

  def test_closure_not_affected_by_later_rebinding
    result = ev('let x = 1 in let f = \y.+ x y in let x = 100 in f 5')
    assert_equal VNum.new(6), result
  end

  def test_closure_church_pair
    result = ev('let pair = \a.\b.\f.f a b in let fst = \p.p (\x.\y.x) in let snd = \p.p (\x.\y.y) in let p = pair 3 7 in + (fst p) (snd p)')
    assert_equal VNum.new(10), result
  end

  def test_closure_compose
    result = ev('let compose = \f.\g.\x.f (g x) in let double = \x.* x 2 in let inc = \x.+ x 1 in compose inc double 3')
    assert_equal VNum.new(7), result
  end

  def test_closure_returned_from_function
    result = ev('let make = \x.\y.+ x y in let f = make 10 in + (f 1) (f 2)')
    assert_equal VNum.new(23), result
  end

  def test_closure_higher_order
    result = ev('let apply = \f.\x.f x in apply (\x.* x x) 4')
    assert_equal VNum.new(16), result
  end

  def test_closure_nested_capture
    result = ev('let a = 1 in let b = 2 in let f = \x.+ a (+ b x) in f 3')
    assert_equal VNum.new(6), result
  end

  # LET BINDINGS

  def test_let
    assert_equal VNum.new(7), ev('let x = 3 in + x 4')
  end

  def test_nested_let
    assert_equal VNum.new(5), ev('let x = 2 in let y = 3 in + x y')
  end

  # STRING OPERATIONS

  def test_string_literal
    assert_equal VStr.new("hello"), ev('"hello"')
  end

  def test_string_concat
    assert_equal VStr.new("hello world"), ev('+ "hello" " world"')
  end

  def test_string_equality_true
    assert_equal VBool.new(true), ev('= "abc" "abc"')
  end

  def test_string_equality_false
    assert_equal VBool.new(false), ev('= "abc" "def"')
  end

  def test_string_less_than
    assert_equal VBool.new(true), ev('< "abc" "def"')
  end

  def test_string_greater_than
    assert_equal VBool.new(true), ev('> "def" "abc"')
  end

  def test_string_length
    assert_equal VNum.new(5), ev('length "hello"')
  end

  def test_string_length_empty
    assert_equal VNum.new(0), ev('length ""')
  end

  def test_string_concat_mixed_type_raises
    assert_raises(RuntimeError) { ev('+ "hello" 42') }
  end

  def test_string_if_equality
    assert_equal VNum.new(1), ev('if (= "yes" "yes") 1 0')
  end

  # LISTS

  def test_empty_list
    assert_equal VNil.new, ev('{}')
  end

  def test_list_literal
    result = ev('{1 2 3}')
    assert_equal "{1 2 3}", result.to_s
  end

  def test_head
    assert_equal VNum.new(1), ev('head {1 2 3}')
  end

  def test_tail
    assert_equal "{2 3}", ev('tail {1 2 3}').to_s
  end

  def test_cons
    assert_equal "{0 1 2}", ev('cons 0 {1 2}').to_s
  end

  def test_isnil_true
    assert_equal VBool.new(true), ev('isnil {}')
  end

  def test_isnil_false
    assert_equal VBool.new(false), ev('isnil {1}')
  end

  def test_head_nil_raises
    assert_raises(RuntimeError) { ev('head {}') }
  end

  def test_tail_nil_raises
    assert_raises(RuntimeError) { ev('tail {}') }
  end

  def test_list_length
    assert_equal VNum.new(3), ev('length {1 2 3}')
  end

  def test_list_length_empty
    assert_equal VNum.new(0), ev('length {}')
  end

  # MAP AND FOLD

  def test_map
    assert_equal "{2 4 6}", ev('map (\x.* x 2) {1 2 3}').to_s
  end

  def test_map_empty
    assert_equal VNil.new, ev('map (\x.* x 2) {}')
  end

  def test_fold
    assert_equal VNum.new(6), ev('fold (\x.\y.+ x y) 0 {1 2 3}')
  end

  def test_fold_empty
    assert_equal VNum.new(0), ev('fold (\x.\y.+ x y) 0 {}')
  end

  # Y COMBINATOR (RECURSION)

  def test_y_sum
    source = 'let sum = Y (\self.\n.if (= n 0) 0 (+ n (self (- n 1)))) in sum 3'
    assert_equal VNum.new(6), ev(source)
  end

  def test_y_factorial
    source = 'let fact = Y (\self.\n.if (= n 0) 1 (* n (self (- n 1)))) in fact 5'
    assert_equal VNum.new(120), ev(source)
  end

  def test_y_with_list
    source = 'let double = Y (\self.\lst.if (isnil lst) {} (cons (* 2 (head lst)) (self (tail lst)))) in double {1 2 3}'
    assert_equal "{2 4 6}", ev(source).to_s
  end

  # DEFINE

  def test_define_simple
    eval = Bukowski::Evaluator.new
    result = eval.evaluate_program("define x 5\nx")
    assert_equal VNum.new(5), result.last
  end

  def test_define_function
    eval = Bukowski::Evaluator.new
    result = eval.evaluate_program("define double \\x.* x 2\ndouble 3")
    assert_equal VNum.new(6), result.last
  end

  def test_define_uses_prior
    eval = Bukowski::Evaluator.new
    result = eval.evaluate_program("define x 5\ndefine y (+ x 1)\ny")
    assert_equal VNum.new(6), result.last
  end

  def test_define_multiple
    eval = Bukowski::Evaluator.new
    source = <<~BK
      define double \\x.* x 2
      define square \\x.* x x
      square (double 3)
    BK
    result = eval.evaluate_program(source)
    assert_equal VNum.new(36), result.last
  end
end
