# frozen_string_literal: true

require_relative 'tokenizer'
require_relative 'parser'
require_relative 'sk_translator'
require_relative 'sk_reducer'

module Bukowski
  # Evaluator that translates LC to SK with caching
  class CachedSKEvaluator
    def initialize
      @translator = SK::Translator.new
      @reducer = SK::Reducer.new
      @translation_cache = {}
    end

    def evaluate(expr)
      sk_expr = @translation_cache[expr] ||= @translator.translate(expr)
      @reducer.reduce(sk_expr)
    end

    # Evaluate a multi-statement program (source string).
    # Splits into line-delimited statements, accumulates defines,
    # and wraps each expression in all prior defines.
    # Returns array of results (one per non-define statement).
    def evaluate_program(source, defines: [])
      results = []

      each_statement(source) do |stmt|
        tokens = Tokenizer.new(stmt).tokenize
        ast = Parser.new(tokens).parse

        if ast.is_a?(Define)
          defines << ast
        else
          wrapped = Parser.wrap_defines(defines, ast)
          results << evaluate(wrapped)
        end
      end

      results
    end

    def cache_size
      @translation_cache.size
    end

    def clear_cache
      @translation_cache.clear
    end

    private

    def each_statement(source)
      buffer = ""
      depth = 0

      source.each_line do |line|
        line.each_char do |c|
          depth += 1 if c == '(' || c == '{'
          depth -= 1 if c == ')' || c == '}'
        end
        buffer += line

        if depth <= 0
          stripped = buffer.strip
          unless stripped.empty? || stripped.start_with?('#')
            yield buffer
          end
          buffer = ""
          depth = 0
        end
      end

      unless buffer.strip.empty?
        yield buffer
      end
    end
  end
end
