require "minitest/autorun"
require_relative "../lib/bukowski/cached_sk_evaluator"
require_relative "../lib/bukowski/prelude"

class TestPrelude < Minitest::Test
  def setup
    @evaluator = Bukowski::CachedSKEvaluator.new
    @defines = Bukowski::Prelude.load_defines(@evaluator)
  end

  def eval(source)
    results = @evaluator.evaluate_program(source, prelude_defines: @defines)
    results.last
  end

  def assert_num(expected, source)
    result = eval(source)
    assert_equal Bukowski::SK::SKNum.new(expected), result, "Expected #{expected} from: #{source}"
  end

  def assert_str(expected, source)
    result = eval(source)
    assert_equal Bukowski::SK::SKStr.new(expected), result, "Expected \"#{expected}\" from: #{source}"
  end

  def assert_church_true(source)
    result = eval(source)
    assert_equal Bukowski::SK::K.new, result, "Expected true from: #{source}"
  end

  def assert_church_false(source)
    result = eval(source)
    expected = Bukowski::SK::SKApp.new(Bukowski::SK::K.new, Bukowski::SK::I.new)
    assert_equal expected, result, "Expected false from: #{source}"
  end

  def assert_list(expected_values, source)
    result = eval(source)
    values = []
    node = result
    while node.is_a?(Bukowski::SK::SKCons)
      values << node.head
      node = node.tail
    end
    assert node.is_a?(Bukowski::SK::SKNil), "Expected nil-terminated list from: #{source}"
    assert_equal expected_values.map { |v| Bukowski::SK::SKNum.new(v) }, values, "List mismatch for: #{source}"
  end

  # === Combinators ===

  def test_id
    assert_num 42, "id 42"
  end

  def test_const
    assert_num 1, "const 1 2"
  end

  def test_compose
    assert_num 10, 'compose (* 2) (+ 3) 2'
  end

  def test_flip
    assert_num 2, 'flip - 3 5'
  end

  def test_apply
    assert_num 5, 'apply (+ 2) 3'
  end

  # === Boolean operations ===

  def test_not_true
    assert_church_false 'not true'
  end

  def test_not_false
    assert_church_true 'not false'
  end

  def test_and_true_true
    assert_church_true 'and true true'
  end

  def test_and_true_false
    assert_church_false 'and true false'
  end

  def test_and_false_true
    assert_church_false 'and false true'
  end

  def test_or_false_false
    assert_church_false 'or false false'
  end

  def test_or_false_true
    assert_church_true 'or false true'
  end

  def test_or_true_false
    assert_church_true 'or true false'
  end

  # === Pairs ===

  def test_fst
    assert_num 1, 'fst (pair 1 2)'
  end

  def test_snd
    assert_num 2, 'snd (pair 1 2)'
  end

  def test_pair_strings
    assert_str "hello", 'fst (pair "hello" "world")'
  end

  # === List utilities ===

  def test_filter
    assert_list [2, 4], 'filter (\x.= (% x 2) 0) {1 2 3 4 5}'
  end

  def test_filter_empty
    result = eval('filter (\x.true) {}')
    assert result.is_a?(Bukowski::SK::SKNil)
  end

  def test_append
    assert_list [1, 2, 3, 4], 'append {1 2} {3 4}'
  end

  def test_append_empty_left
    assert_list [1, 2], 'append {} {1 2}'
  end

  def test_append_empty_right
    assert_list [1, 2], 'append {1 2} {}'
  end

  def test_reverse
    assert_list [3, 2, 1], 'reverse {1 2 3}'
  end

  def test_reverse_empty
    result = eval('reverse {}')
    assert result.is_a?(Bukowski::SK::SKNil)
  end

  def test_nth
    assert_num 3, 'nth 2 {1 2 3 4}'
  end

  def test_nth_zero
    assert_num 1, 'nth 0 {1 2 3}'
  end

  def test_take
    assert_list [1, 2], 'take 2 {1 2 3 4}'
  end

  def test_take_more_than_length
    assert_list [1, 2], 'take 5 {1 2}'
  end

  def test_take_zero
    result = eval('take 0 {1 2 3}')
    assert result.is_a?(Bukowski::SK::SKNil)
  end

  def test_drop
    assert_list [3, 4], 'drop 2 {1 2 3 4}'
  end

  def test_drop_zero
    assert_list [1, 2, 3], 'drop 0 {1 2 3}'
  end

  def test_drop_all
    result = eval('drop 5 {1 2}')
    assert result.is_a?(Bukowski::SK::SKNil)
  end

  def test_zip
    result = eval('zip {1 2 3} {4 5 6}')
    node = result
    pairs = []
    while node.is_a?(Bukowski::SK::SKCons)
      pair = node.head
      assert pair.is_a?(Bukowski::SK::SKCons)
      a = pair.head
      b = pair.tail.head
      pairs << [a.value, b.value]
      node = node.tail
    end
    assert_equal [[1, 4], [2, 5], [3, 6]], pairs
  end

  def test_zip_unequal
    result = eval('zip {1 2} {3}')
    node = result
    pairs = []
    while node.is_a?(Bukowski::SK::SKCons)
      pair = node.head
      pairs << [pair.head.value, pair.tail.head.value]
      node = node.tail
    end
    assert_equal [[1, 3]], pairs
  end

  def test_any_true
    assert_church_true 'any (\x.= x 3) {1 2 3}'
  end

  def test_any_false
    assert_church_false 'any (\x.= x 5) {1 2 3}'
  end

  def test_all_true
    assert_church_true 'all (\x.> x 0) {1 2 3}'
  end

  def test_all_false
    assert_church_false 'all (\x.> x 1) {1 2 3}'
  end

  def test_sum
    assert_num 10, 'sum {1 2 3 4}'
  end

  def test_sum_empty
    assert_num 0, 'sum {}'
  end

  def test_product
    assert_num 24, 'product {1 2 3 4}'
  end

  def test_product_empty
    assert_num 1, 'product {}'
  end

  # === show and parse builtins ===

  def test_show_number
    assert_str "42", 'show 42'
  end

  def test_show_negative
    assert_str "-5", 'show (- 0 5)'
  end

  def test_show_string_passthrough
    assert_str "hello", 'show "hello"'
  end

  def test_show_nil
    assert_str "{}", 'show {}'
  end

  def test_show_in_concat
    assert_str "value: 42", '+ "value: " (show 42)'
  end

  def test_parse_integer
    assert_num 42, 'parse "42"'
  end

  def test_parse_negative
    assert_num(-7, 'parse "-7"')
  end

  def test_parse_with_spaces
    assert_num 10, 'parse " 10 "'
  end

  def test_parse_then_add
    assert_num 15, '+ (parse "10") 5'
  end

  def test_parse_non_number_raises
    assert_raises(RuntimeError) { eval('parse "abc"') }
  end

  # === Composition ===

  def test_compose_with_prelude
    assert_num 12, 'sum (filter (\x.= (% x 2) 0) {1 2 3 4 5 6})'
  end

  def test_map_with_show
    result = eval('map show {1 2 3}')
    values = []
    node = result
    while node.is_a?(Bukowski::SK::SKCons)
      values << node.head.value
      node = node.tail
    end
    assert_equal ["1", "2", "3"], values
  end

  def test_prelude_count
    assert_equal 22, @defines.length
  end
end
