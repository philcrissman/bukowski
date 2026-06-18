# frozen_string_literal: true

require_relative 'cached_sk_evaluator'

module Bukowski
  class StreamRunner
    def initialize(input: $stdin, output: $stdout)
      @input = input
      @output = output
      @evaluator = CachedSKEvaluator.new
      @reducer = SK::Reducer.new
    end

    def run(source)
      defines = []
      program = nil

      @evaluator.send(:each_statement, source) do |stmt|
        tokens = Tokenizer.new(stmt).tokenize
        ast = Parser.new(tokens).parse

        if ast.is_a?(Define)
          defines << ast
        else
          wrapped = Parser.wrap_defines(defines, ast)
          program = @evaluator.evaluate(wrapped)
        end
      end

      return unless program

      if program.is_a?(SK::SKCons) || program.is_a?(SK::SKNil)
        walk_output(program)
      else
        input_list = build_input_list
        output_list = @reducer.reduce(SK::SKApp.new(program, input_list))
        walk_output(output_list)
      end
    end

    private

    def build_input_list
      SK::SKLazy.new { read_next }
    end

    def read_next
      line = @input.gets
      if line
        SK::SKCons.new(
          SK::SKStr.new(line.chomp),
          SK::SKLazy.new { read_next }
        )
      else
        SK::SKNil.new
      end
    end

    def walk_output(expr)
      node = force_reduce(expr)

      while node.is_a?(SK::SKCons)
        head = force_reduce(node.head)
        if head.is_a?(SK::SKStr)
          @output.puts head.value
        else
          @output.puts head.to_s
        end
        @output.flush
        node = force_reduce(node.tail)
      end
    end

    def force_reduce(expr)
      expr = expr.force while expr.is_a?(SK::SKLazy)
      @reducer.reduce(expr)
    end
  end
end
