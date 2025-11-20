# frozen_string_literal: true

module Bukowski
  Token = Struct.new(:type, :value) do
    def to_s
      value ? "#{type}(#{value.to_s})" : type.to_s
    end
  end

  class Tokenizer
    def initialize input
      @input = input
      @pos = 0
      @tokens = []
    end

    def tokenize
      while !eof?
        skip_whitespace
        break if eof?
        @tokens << next_token
      end
      @tokens << Token.new(:EOF)
      @tokens
    end

    private

    def eof?
      @pos >= @input.size
    end

    def advance
      @pos += 1
    end

    def current_char
      @input[@pos]
    end

    def next_token
      c = current_char

      case c
      when '\\', 'λ'
        advance
        Token.new(:LAM)
      when '.'
        advance
        Token.new(:DOT)
      when '('
        advance
        Token.new(:LPAREN)
      when ')'
        advance
        Token.new(:RPAREN)
      when 'a'..'z', 'A'..'Z'
        advance
        Token.new(:VAR, c)
      else
        raise "Unexpected character: #{c.inspect}"
      end
    end

    def skip_whitespace
      advance while !eof? && current_char =~ /\s/
    end
  end
end
