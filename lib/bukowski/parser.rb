module Bukowski
  Var = Struct.new(:name) do
    def to_s
      name
    end
  end
  Abs = Struct.new(:param, :body) do
    def to_s
      "λ#{param}.#{body}"
    end
  end
  App = Struct.new(:func, :arg) do
    def to_s
      func_str = func.is_a?(Abs) ? "(#{func})" : func.to_s
      arg_str = arg.is_a?(Abs) ? "(#{arg})" : arg.to_s
      "#{func_str} #{arg_str}"
    end
  end

  class Parser
    def initialize(tokens)
      @tokens = tokens
      @pos = 0
    end

    def parse
      parse_expr
    end

    private

    def current_token
      @tokens[@pos]
    end

    def advance
      @pos += 1
    end

    def expect(type)
      raise "Expected #{type}, but found #{current_token.type}." unless current_token.type == type
      token = current_token
      advance
      token
    end

    def parse_expr
      if current_token.type == :LAM
        parse_abstraction
      else
        parse_application
      end
    end

    def parse_abstraction
      expect(:LAM)
      param = expect(:VAR).value
      expect(:DOT)
      body = parse_expr
      Abs.new(param, body)
    end

    def parse_application
      left = parse_atom
      
      while current_token.type == :VAR || current_token.type == :LPAREN
        right = parse_atom
        left = App.new(left, right)
      end

      left
    end

    def parse_atom
      case current_token.type
      when :VAR
        var = Var.new(current_token.value)
        advance
        var
      when :LPAREN
        advance
        expr = parse_expr
        expect(:RPAREN)
        expr
      else
        raise "Unexpected token: #{current_token}"
      end
    end
  end
end
