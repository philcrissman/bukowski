# repl.rb
require_relative 'tokenizer'
require_relative 'parser'
require_relative 'evaluator'

module Bukowski
  class REPL
    def run
      puts "Bukowski Lambda Calculus REPL"
      puts "Enter expressions (Ctrl+D to exit)"
      puts
      
      loop do
        print "λ> "
        input = gets
        break unless input  # Ctrl+D
        
        input = input.strip
        next if input.empty?
        
        begin
          tokens = Tokenizer.new(input).tokenize
          ast = Parser.new(tokens).parse
          result = Evaluator.new.evaluate(ast)
          puts "=> #{result}"
        rescue => e
          puts "Error: #{e.message}"
        end
      end
      
      puts "\nGoodbye!"
    end
  end
end
