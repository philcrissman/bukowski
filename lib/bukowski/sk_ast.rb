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

    # Empty list
    class SKNil
      def to_s
        "{}"
      end

      def ==(other)
        other.is_a?(SKNil)
      end

      def inspect
        "SKNil"
      end
    end

    # Cons cell (head, tail)
    SKCons = Struct.new(:head, :tail) do
      def to_s
        elements = []
        current = self
        while current.is_a?(SKCons)
          elements << current.head.to_s
          current = current.tail
        end
        if current.is_a?(SKNil)
          "{#{elements.join(' ')}}"
        else
          "{#{elements.join(' ')} . #{current}}"
        end
      end

      def inspect
        "#<SKCons #{head.inspect} #{tail.inspect}>"
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

    # Doubly partially applied operator (for 3-arg operations like fold)
    SKPartialOp2 = Struct.new(:op, :arg1, :arg2) do
      def to_s
        "(#{op} #{arg1} #{arg2} ...)"
      end

      def inspect
        "#<SKPartialOp2 #{op} #{arg1} #{arg2}>"
      end
    end
  end
end
