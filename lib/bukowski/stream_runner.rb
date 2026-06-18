# frozen_string_literal: true

require_relative 'cached_sk_evaluator'
require_relative 'prelude'

module Bukowski
  class StreamRunner
    attr_reader :exit_code

    def initialize(input: $stdin, output: $stdout, fs: nil, no_prelude: false)
      @input = input
      @output = output
      @fs = fs || RealFS.new
      @no_prelude = no_prelude
      @evaluator = CachedSKEvaluator.new
      @reducer = SK::Reducer.new(lazy_cons: true)
      @responses = []
      @response_index = 0
      @exit_code = nil
    end

    def run(source)
      defines = @no_prelude ? [] : Prelude.load_defines(@evaluator)
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
      SK::SKLazy.new { next_response }
    end

    def next_response
      if @response_index < @responses.length
        val = @responses[@response_index]
        @response_index += 1
        SK::SKCons.new(val, SK::SKLazy.new { next_response })
      else
        line = @input.gets
        if line
          val = SK::SKStr.new(line.chomp)
          SK::SKCons.new(val, SK::SKLazy.new { next_response })
        else
          SK::SKNil.new
        end
      end
    end

    def push_response(val)
      @responses << val
    end

    def walk_output(expr)
      node = force_reduce(expr)

      while node.is_a?(SK::SKCons)
        head = force_reduce(node.head)
        dispatch(head)
        break if @exit_code
        node = force_reduce(node.tail)
      end
    end

    def dispatch(element)
      if element.is_a?(SK::SKCons)
        tag = force_reduce(element.head)
        if tag.is_a?(SK::SKStr)
          dispatch_request(tag.value, element.tail)
          return
        end
      end

      if element.is_a?(SK::SKStr)
        @output.puts element.value
      else
        @output.puts element.to_s
      end
      @output.flush
    end

    def dispatch_request(tag, args)
      case tag
      when 'Print'
        msg = force_reduce(cons_head(args))
        if msg.is_a?(SK::SKStr)
          @output.puts msg.value
        else
          @output.puts msg.to_s
        end
        @output.flush
      when 'Read'
        line = @input.gets
        val = line ? SK::SKStr.new(line.chomp) : SK::SKStr.new("")
        push_response(val)
      when 'ReadFile'
        path = force_reduce(cons_head(args))
        contents = @fs.read(path.is_a?(SK::SKStr) ? path.value : path.to_s)
        push_response(SK::SKStr.new(contents))
      when 'WriteFile'
        path = force_reduce(cons_head(args))
        contents_node = force_reduce(cons_head(force_reduce(cons_tail(args))))
        path_str = path.is_a?(SK::SKStr) ? path.value : path.to_s
        contents_str = contents_node.is_a?(SK::SKStr) ? contents_node.value : contents_node.to_s
        @fs.write(path_str, contents_str)
        push_response(SK::SKStr.new(""))
      when 'Exit'
        code = force_reduce(cons_head(args))
        @exit_code = code.is_a?(SK::SKNum) ? code.value : 0
      else
        @output.puts "{#{tag} ...}"
        @output.flush
      end
    end

    def cons_head(expr)
      node = force_reduce(expr)
      raise "expected cons, got #{node.class}" unless node.is_a?(SK::SKCons)
      node.head
    end

    def cons_tail(expr)
      node = force_reduce(expr)
      raise "expected cons, got #{node.class}" unless node.is_a?(SK::SKCons)
      node.tail
    end

    def force_reduce(expr)
      expr = expr.force while expr.is_a?(SK::SKLazy)
      @reducer.reduce(expr)
    end

    class RealFS
      def read(path)
        File.read(path)
      end

      def write(path, contents)
        File.write(path, contents)
      end
    end
  end
end
