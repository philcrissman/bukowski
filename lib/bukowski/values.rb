# frozen_string_literal: true

module Bukowski
  module Val
    VNum = Struct.new(:value) do
      def to_s
        value.to_s
      end
    end

    VStr = Struct.new(:value) do
      def to_s
        "\"#{value}\""
      end
    end

    VBool = Struct.new(:value) do
      def to_s
        value.to_s
      end
    end

    VClosure = Struct.new(:param, :body, :env) do
      def to_s
        "λ#{param}.<closure>"
      end
    end

    class VNil
      def to_s
        "{}"
      end

      def ==(other)
        other.is_a?(VNil)
      end

      def inspect
        "VNil"
      end
    end

    VCons = Struct.new(:head, :tail) do
      def to_s
        elements = []
        current = self
        while current.is_a?(VCons)
          elements << current.head.to_s
          current = current.tail
        end
        if current.is_a?(VNil)
          "{#{elements.join(' ')}}"
        else
          "{#{elements.join(' ')} . #{current}}"
        end
      end
    end

    VBuiltin = Struct.new(:name, :impl) do
      def to_s
        "<builtin:#{name}>"
      end
    end

    class VYCombinator
      attr_reader :f

      def initialize(f)
        @f = f
      end

      def to_s
        "<Y ...>"
      end

      def ==(other)
        other.is_a?(VYCombinator) && other.f == @f
      end
    end
  end
end
