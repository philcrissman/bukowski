# repl.rb
require_relative 'tokenizer'
require_relative 'parser'
require_relative 'cached_sk_evaluator'
require_relative 'prelude'

module Bukowski
  class REPL
    def initialize(no_prelude: false)
      @no_prelude = no_prelude
    end

    def run
      puts "Bukowski REPL (SK Combinator based)"
      puts "Enter expressions (Ctrl+D to exit)"
      puts

      evaluator = CachedSKEvaluator.new
      defines = @no_prelude ? [] : Prelude.load_defines(evaluator)

      loop do
        buffer = ""
        depth = 0
        prompt = "λ> "

        loop do
          print prompt
          line = gets
          unless line
            # Ctrl+D
            puts "\nGoodbye!"
            return
          end

          buffer += line
          line.each_char do |c|
            depth += 1 if c == '(' || c == '{'
            depth -= 1 if c == ')' || c == '}'
          end
          break if depth <= 0
          prompt = ".. "
        end

        input = buffer.strip
        next if input.empty?

        begin
          tokens = Tokenizer.new(input).tokenize
          ast = Parser.new(tokens).parse

          if ast.is_a?(Define)
            defines << ast
            puts "defined: #{ast.name}"
          else
            wrapped = Parser.wrap_defines(defines, ast)
            result = evaluator.evaluate(wrapped)

            # Pretty print Church booleans
            if boolean = sk_church_boolean?(result)
              puts "=> #{boolean}"
            else
              puts "=> #{result}"
            end
          end
        rescue => e
          puts "Error: #{e.message}"
        end
      end
    end

    private

    # Detect Church booleans in SK form
    def sk_church_boolean?(expr)
      case expr
      when SK::K
        :true
      when SK::SKApp
        if expr.func.is_a?(SK::K) && expr.arg.is_a?(SK::I)
          :false
        else
          nil
        end
      else
        nil
      end
    end
  end
end
