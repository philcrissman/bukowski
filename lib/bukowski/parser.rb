module Bukowski
  Var = Struct.new(:name) do
    def to_s
      name
    end
  end
  Num = Struct.new(:value) do
    def to_s
      value.to_s
    end
  end
  Str = Struct.new(:value) do
    def to_s
      "\"#{value}\""
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

    def parse_all
      expressions = []
      while current_token.type != :EOF
        expressions << parse_expr
      end
      expressions
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
      elsif current_token.type == :LET
        parse_let
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

    def parse_let
      expect(:LET)
      var = expect(:VAR).value
      # Expect = sign
      raise "Expected '=' in let binding" unless current_token.type == :OP && current_token.value == '='
      advance
      value = parse_expr
      expect(:IN)
      body = parse_expr
      # Desugar: let x = v in b  =>  (λx.b) v
      App.new(Abs.new(var, body), value)
    end

    def parse_application
      left = parse_atom

      while [:VAR, :OP, :NUM, :STR, :LPAREN, :TRUE, :FALSE, :IF].include?(current_token.type)
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
      when :OP
        var = Var.new(current_token.value)
        advance
        var
      when :NUM
        num = Num.new(current_token.value)
        advance
        num
      when :STR
        str = Str.new(current_token.value)
        advance
        str
      when :TRUE
        advance
        Var.new('true')
      when :FALSE
        advance
        Var.new('false')
      when :IF
        advance
        Var.new('if')
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
