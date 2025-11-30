# repl.rb
require_relative 'tokenizer'
require_relative 'parser'
require_relative 'cached_sk_evaluator'

module Bukowski
  class REPL
    def run
      puts "Bukowski REPL (SK Combinator based)"
      puts "Enter expressions (Ctrl+D to exit)"
      puts

      evaluator = CachedSKEvaluator.new

      loop do
        print "λ> "
        input = gets
        break unless input  # Ctrl+D

        input = input.strip
        next if input.empty?

        begin
          tokens = Tokenizer.new(input).tokenize
          ast = Parser.new(tokens).parse
          result = evaluator.evaluate(ast)

          # Pretty print Church booleans
          if boolean = sk_church_boolean?(result)
            puts "=> #{boolean}"
          else
            puts "=> #{result}"
          end
        rescue => e
          puts "Error: #{e.message}"
        end
      end

      puts "\nGoodbye!"
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
