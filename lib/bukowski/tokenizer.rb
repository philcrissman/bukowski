# frozen_string_literal: true

module Bukowski
  Token = Struct.new(:type, :value) do
    def to_s
      value ? "#{type}(#{value.inspect})" : type.to_s
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

    def skip_whitespace
      advance while !eof? && current_char =~ /\s/
    end

    def next_token
      c = current_char

      case c 
      when '\\', 'λ' then advance; Token.new(:LAM)
      when '.' then advance; Token.new(:DOT)
      when '(' then advance; Token.new(:LPAREN)
      when ')' then advance; Token.new(:RPAREN)
      when '"' then read_string
      when /[0-9]/ then read_int
      when /[a-zA-Z_+\-*\/=<>!]/
        read_identifier
      else
        raise "Unexpected character: #{c.inspect}"
      end
    end

    def read_identifier
      start = @pos
      advance while !eof? && current_char =~ /[a-zA-Z0-9_+\-*\/=<>!]/
      value = @input[start...@pos]
      Token.new(:IDENT, value)
    end

    def read_int
      start = @pos
      advance while !eof? && current_char =~ /[0-9]/
      value = @input[start...@pos].to_i
      Token.new(:INT, value)
    end

    def read_string
      advance # skip "
      str = ""
      buffer = str.dup
      until eof?
        c = current_char
        if c == '"'
          advance
          return Token.new(:STRING, buffer)
        elsif c == '\\' && peek == '"'
          buffer << '"'
          advance; advance
        elsif c == '\\' && peek == '\\'
          buffer << '\\'
          advance; advance
        elsif c == '\\' && peek == 'n'
          buffer << "\n"
          advance; advance
        elsif c == '\\' && peek == 't'
          buffer << "\t"
          advance; advance
        else
          buffer << c
          advance
        end
      end
      raise "Unterminated string literal"
    end

    def advance
      @pos += 1
    end

    def eof?
      @pos >= @input.size
    end

    def current_char
      @input[@pos]
    end

    def peek
      @input[@pos + 1]
    end
  end
end
