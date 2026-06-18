require "minitest/autorun"
require "stringio"
require "tempfile"
require_relative "../lib/bukowski/stream_runner"

class MockFS
  attr_reader :written

  def initialize(files = {})
    @files = files
    @written = {}
  end

  def read(path)
    @files.fetch(path) { raise "File not found: #{path}" }
  end

  def write(path, contents)
    @written[path] = contents
  end
end

class TestStreamRunner < Minitest::Test
  def run_io(source, input_text = "", fs: nil)
    input = StringIO.new(input_text)
    output = StringIO.new
    opts = { input: input, output: output }
    opts[:fs] = fs if fs
    runner = Bukowski::StreamRunner.new(**opts)
    runner.run(source)
    [output.string, runner]
  end

  # === Phase 1 backward compatibility ===

  def test_constant_output
    source = 'cons "hello" (cons "world" {})'
    result, _ = run_io(source)
    assert_equal "hello\nworld\n", result
  end

  def test_single_output
    source = 'cons "hi" {}'
    result, _ = run_io(source)
    assert_equal "hi\n", result
  end

  def test_empty_output
    source = '{}'
    result, _ = run_io(source)
    assert_equal "", result
  end

  def test_echo_one_line
    source = <<~BK
      \\input. cons (head input) {}
    BK
    result, _ = run_io(source, "hello\n")
    assert_equal "hello\n", result
  end

  def test_greeting_program
    source = <<~BK
      \\input. cons "What is your name?" (cons (+ "Hello, " (head input)) {})
    BK
    result, _ = run_io(source, "Alice\n")
    assert_equal "What is your name?\nHello, Alice\n", result
  end

  def test_no_input_needed
    source = <<~BK
      \\input. cons "no input needed" {}
    BK
    result, _ = run_io(source, "")
    assert_equal "no input needed\n", result
  end

  def test_numeric_output
    source = 'cons 42 {}'
    result, _ = run_io(source)
    assert_equal "42\n", result
  end

  def test_with_defines
    source = <<~BK
      define greeting "Hello!"
      cons greeting {}
    BK
    result, _ = run_io(source)
    assert_equal "Hello!\n", result
  end

  def test_define_function_with_io
    source = <<~BK
      define greet \\input. cons "Name?" (cons (+ "Hi, " (head input)) {})
      greet
    BK
    result, _ = run_io(source, "Bob\n")
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
    result, _ = run_io(source, "first\nsecond\n")
    assert_equal "first\nsecond\n", result
  end

  def test_transform_input
    source = <<~BK
      \\input. cons (+ ">> " (head input)) {}
    BK
    result, _ = run_io(source, "test\n")
    assert_equal ">> test\n", result
  end

  def test_nil_program_does_nothing
    source = 'define x 42'
    result, _ = run_io(source)
    assert_equal "", result
  end

  # === Phase 2: Request/Response Protocol ===

  def test_print_request
    source = 'cons {"Print" "hello"} {}'
    result, _ = run_io(source)
    assert_equal "hello\n", result
  end

  def test_multiple_print_requests
    source = 'cons {"Print" "one"} (cons {"Print" "two"} {})'
    result, _ = run_io(source)
    assert_equal "one\ntwo\n", result
  end

  def test_read_request
    source = '\\input. cons {"Read"} (cons {"Print" (head input)} {})'
    result, _ = run_io(source, "hello\n")
    assert_equal "hello\n", result
  end

  def test_read_then_greet
    source = '\\input. cons {"Print" "Name?"} (cons {"Read"} (cons {"Print" (+ "Hi, " (head input))} {}))'
    result, _ = run_io(source, "Alice\n")
    assert_equal "Name?\nHi, Alice\n", result
  end

  def test_multiple_reads
    source = '\\input. cons {"Read"} (cons {"Read"} (cons {"Print" (+ (head input) (+ " and " (head (tail input))))} {}))'
    result, _ = run_io(source, "first\nsecond\n")
    assert_equal "first and second\n", result
  end

  def test_exit_request
    source = 'cons {"Print" "before"} (cons {"Exit" 0} (cons {"Print" "after"} {}))'
    result, runner = run_io(source)
    assert_equal "before\n", result
    assert_equal 0, runner.exit_code
  end

  def test_exit_with_code
    source = 'cons {"Exit" 42} {}'
    _, runner = run_io(source)
    assert_equal 42, runner.exit_code
  end

  def test_read_file_request
    fs = MockFS.new("/tmp/test.txt" => "file contents here")
    source = '\\input. cons {"ReadFile" "/tmp/test.txt"} (cons {"Print" (head input)} {})'
    result, _ = run_io(source, "", fs: fs)
    assert_equal "file contents here\n", result
  end

  def test_write_file_request
    fs = MockFS.new
    source = 'cons {"WriteFile" "out.txt" "data"} {}'
    run_io(source, "", fs: fs)
    assert_equal "data", fs.written["out.txt"]
  end

  def test_write_then_read_file
    fs = MockFS.new
    source = '\\input. cons {"WriteFile" "/tmp/f.txt" "saved"} (cons {"Print" (+ "wrote: " (head input))} {})'
    result, _ = run_io(source, "", fs: fs)
    assert_equal "saved", fs.written["/tmp/f.txt"]
    assert_equal "wrote: \n", result
  end

  def test_mixed_plain_and_tagged
    source = 'cons "plain" (cons {"Print" "tagged"} {})'
    result, _ = run_io(source)
    assert_equal "plain\ntagged\n", result
  end

  def test_unknown_tag_printed
    source = 'cons {"Unknown" "data"} {}'
    result, _ = run_io(source)
    assert_equal "{Unknown ...}\n", result
  end
end
