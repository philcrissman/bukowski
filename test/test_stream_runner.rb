require "minitest/autorun"
require "stringio"
require_relative "../lib/bukowski/stream_runner"

class TestStreamRunner < Minitest::Test
  def run_io(source, input_text = "")
    input = StringIO.new(input_text)
    output = StringIO.new
    runner = Bukowski::StreamRunner.new(input: input, output: output)
    runner.run(source)
    output.string
  end

  def test_constant_output
    source = 'cons "hello" (cons "world" {})'
    result = run_io(source)
    assert_equal "hello\nworld\n", result
  end

  def test_single_output
    source = 'cons "hi" {}'
    result = run_io(source)
    assert_equal "hi\n", result
  end

  def test_empty_output
    source = '{}'
    result = run_io(source)
    assert_equal "", result
  end

  def test_echo_one_line
    source = <<~BK
      \\input. cons (head input) {}
    BK
    result = run_io(source, "hello\n")
    assert_equal "hello\n", result
  end

  def test_greeting_program
    source = <<~BK
      \\input. cons "What is your name?" (cons (+ "Hello, " (head input)) {})
    BK
    result = run_io(source, "Alice\n")
    assert_equal "What is your name?\nHello, Alice\n", result
  end

  def test_no_input_needed
    source = <<~BK
      \\input. cons "no input needed" {}
    BK
    result = run_io(source, "")
    assert_equal "no input needed\n", result
  end

  def test_numeric_output
    source = 'cons 42 {}'
    result = run_io(source)
    assert_equal "42\n", result
  end

  def test_with_defines
    source = <<~BK
      define greeting "Hello!"
      cons greeting {}
    BK
    result = run_io(source)
    assert_equal "Hello!\n", result
  end

  def test_define_function_with_io
    source = <<~BK
      define greet \\input. cons "Name?" (cons (+ "Hi, " (head input)) {})
      greet
    BK
    result = run_io(source, "Bob\n")
    assert_equal "Name?\nHi, Bob\n", result
  end

  def test_input_not_forced_when_not_needed
    source = 'cons "done" {}'
    input = StringIO.new("")
    output = StringIO.new
    runner = Bukowski::StreamRunner.new(input: input, output: output)
    runner.run(source)
    assert_equal 0, input.pos
  end

  def test_multiple_input_lines
    source = <<~BK
      \\input. cons (head input) (cons (head (tail input)) {})
    BK
    result = run_io(source, "first\nsecond\n")
    assert_equal "first\nsecond\n", result
  end

  def test_transform_input
    source = <<~BK
      \\input. cons (+ ">> " (head input)) {}
    BK
    result = run_io(source, "test\n")
    assert_equal ">> test\n", result
  end

  def test_nil_program_does_nothing
    source = 'define x 42'
    result = run_io(source)
    assert_equal "", result
  end
end
