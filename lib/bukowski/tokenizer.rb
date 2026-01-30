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
      when '{'
        advance
        Token.new(:LBRACE)
      when '}'
        advance
        Token.new(:RBRACE)
      when '0'..'9'
        num = String.new
        while !eof? && current_char =~ /[0-9]/
          num << current_char
          advance
        end
        # Check for decimal point (float)
        if !eof? && current_char == '.'
          # Look ahead - only treat as decimal if followed by digit
          if @pos + 1 < @input.size && @input[@pos + 1] =~ /[0-9]/
            num << current_char
            advance
            while !eof? && current_char =~ /[0-9]/
              num << current_char
              advance
            end
            Token.new(:NUM, num.to_f)
          else
            # Not a decimal, just return integer
            Token.new(:NUM, num.to_i)
          end
        else
          Token.new(:NUM, num.to_i)
        end
      when 'a'..'z', 'A'..'Z'
        word = String.new
        while !eof? && current_char =~ /[a-zA-Z]/
          word << current_char
          advance
        end

        case word
        when 'true'   then Token.new(:TRUE)
        when 'false'  then Token.new(:FALSE)
        when 'if'     then Token.new(:IF)
        when 'let'    then Token.new(:LET)
        when 'in'     then Token.new(:IN)
        when 'define' then Token.new(:DEFINE)
        else Token.new(:VAR, word)
        end
      when '+', '-', '*', '/', '%', '=', '<', '>'
        advance
        Token.new(:OP, c)
      when '"'
        # String literal
        advance  # Skip opening quote
        str = String.new
        while !eof? && current_char != '"'
          if current_char == '\\'
            # Handle escape sequences
            advance
            unless eof?
              case current_char
              when 'n' then str << "\n"
              when 't' then str << "\t"
              when 'r' then str << "\r"
              when '\\' then str << "\\"
              when '"' then str << "\""
              else str << current_char
              end
              advance
            end
          else
            str << current_char
            advance
          end
        end
        advance if !eof?  # Skip closing quote
        Token.new(:STR, str)
      else
        raise "Unexpected character: #{c.inspect}"
      end
    end

    def skip_whitespace
      while !eof?
        if current_char =~ /\s/
          advance
        elsif current_char == '#'
          # Skip comment until end of line
          advance while !eof? && current_char != "\n"
          advance if !eof?  # Skip the newline too
        else
          break
        end
      end
    end
  end
end
