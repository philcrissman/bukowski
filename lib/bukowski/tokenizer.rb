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
      when '0'..'9'
        num = String.new
        while !eof? && current_char =~ /[0-9]/
          num << current_char
          advance
        end
        Token.new(:NUM, num.to_i)
      when 'a'..'z', 'A'..'Z'
        word = String.new
        while !eof? && current_char =~ /[a-zA-Z]/
          word << current_char
          advance
        end

        case word
        when 'true'  then Token.new(:TRUE)
        when 'false' then Token.new(:FALSE)
        when 'if'    then Token.new(:IF)
        else Token.new(:VAR, word)
        end
      when '+', '-', '*', '/', '=', '<', '>'
        advance
        Token.new(:OP, c)
      else
        raise "Unexpected character: #{c.inspect}"
      end
    end

    def skip_whitespace
      advance while !eof? && current_char =~ /\s/
    end
  end
end
