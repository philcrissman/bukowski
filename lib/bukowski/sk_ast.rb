# frozen_string_literal: true

module Bukowski
  module SK
    # S combinator: S x y z = x z (y z)
    class S
      def to_s
        "S"
      end

      def ==(other)
        other.is_a?(S)
      end

      def inspect
        "S"
      end
    end

    # K combinator: K x y = x
    class K
      def to_s
        "K"
      end

      def ==(other)
        other.is_a?(K)
      end

      def inspect
        "K"
      end
    end

    # I combinator: I x = x
    class I
      def to_s
        "I"
      end

      def ==(other)
        other.is_a?(I)
      end

      def inspect
        "I"
      end
    end

    # Application in SK calculus
    SKApp = Struct.new(:func, :arg) do
      def to_s
        func_str = needs_parens?(func) ? "(#{func})" : func.to_s
        arg_str = needs_parens?(arg) ? "(#{arg})" : arg.to_s
        "#{func_str} #{arg_str}"
      end

      def inspect
        "#<SKApp #{func.inspect} #{arg.inspect}>"
      end

      private

      def needs_parens?(expr)
        expr.is_a?(SKApp)
      end
    end

    # Number literal in SK calculus (primitive)
    SKNum = Struct.new(:value) do
      def to_s
        value.to_s
      end

      def inspect
        "#<SKNum #{value}>"
      end
    end

    # String literal in SK calculus (primitive)
    SKStr = Struct.new(:value) do
      def to_s
        "\"#{value}\""
      end

      def inspect
        "#<SKStr #{value}>"
      end
    end

    # Variable in SK calculus (for operators and free variables)
    SKVar = Struct.new(:name) do
      def to_s
        name
      end

      def inspect
        "#<SKVar #{name}>"
      end
    end

    # Partially applied operator (for primitive operations)
    SKPartialOp = Struct.new(:op, :arg) do
      def to_s
        "(#{op} #{arg} ...)"
      end

      def inspect
        "#<SKPartialOp #{op} #{arg}>"
      end
    end
  end
end
