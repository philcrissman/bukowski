# frozen_string_literal: true

require_relative 'sk_ast'

module Bukowski
  module SK
    class Reducer
      def reduce(expr)
        case expr
        when S, K, I
          # Combinators are values
          expr
        when SKNum
          # Numbers are values
          expr
        when SKStr
          # Strings are values
          expr
        when SKVar
          # Check if it's a Church boolean or 'if'
          case expr.name
          when 'true'
            # Church true in SK: K
            K.new
          when 'false'
            # Church false in SK: K I
            SKApp.new(K.new, I.new)
          when 'if'
            # if is identity for Church booleans: I
            I.new
          else
            # Other variables (operators, free vars) stay as-is
            expr
          end
        when SKPartialOp
          # Partially applied operators are values
          expr
        when SKApp
          # LAZY: Reduce the function, but NOT the argument
          func = reduce(expr.func)

          # Pattern match on reduced function
          case func
          when I
            # I x = x
            # Don't reduce x BEFORE applying I (lazy)
            # But DO reduce the result (to reach normal form)
            reduce(expr.arg)
          when K
            # K x is a value (waiting for second arg)
            # Store argument WITHOUT reducing it
            SKApp.new(func, expr.arg)
          when S
            # S x is a value (waiting for more args)
            SKApp.new(func, expr.arg)
          when SKApp
            reduce_application(func, expr.arg)
          when SKVar
            # Check if it's a primitive operator
            if ['+', '-', '*', '/', '%', '=', '<', '>'].include?(func.name)
              # Primitives are STRICT: reduce arg to get value
              SKPartialOp.new(func.name, reduce(expr.arg))
            else
              # Unknown variable - LAZY: don't reduce arg
              SKApp.new(func, expr.arg)
            end
          when SKPartialOp
            # Primitives are STRICT: reduce second arg
            apply_primitive(func.op, func.arg, reduce(expr.arg))
          when SKStr
            # String applied to something? Just return as-is (shouldn't happen normally)
            SKApp.new(func, expr.arg)
          else
            # General case - LAZY: don't reduce arg
            SKApp.new(func, expr.arg)
          end
        else
          expr
        end
      end

      private

      def reduce_application(func, arg)
        # func is an SKApp, check what it contains
        case func.func
        when K
          # (K x) y = x
          # x wasn't reduced before K (lazy), but reduce result to normal form
          reduce(func.arg)
        when S
          # (S x) y - needs one more arg
          # LAZY: Store arg without reducing
          SKApp.new(func, arg)
        when SKApp
          # Check if it's ((S x) y) - fully applied S
          if func.func.func.is_a?(S)
            # S x y z = x z (y z)
            x = func.func.arg
            y = func.arg
            z = arg

            # Build: (x z) (y z)
            # Since S disappears, we continue reducing the result
            xz = SKApp.new(x, z)
            yz = SKApp.new(y, z)
            reduce(SKApp.new(xz, yz))
          else
            # Not a fully applied S - LAZY: don't reduce arg
            SKApp.new(func, arg)
          end
        else
          # General application - LAZY: don't reduce arg
          SKApp.new(func, arg)
        end
      end

      def apply_primitive(op, a, b)
        # Extract numeric values
        a_val = a.is_a?(SKNum) ? a.value : a
        b_val = b.is_a?(SKNum) ? b.value : b

        case op
        when '+'
          SKNum.new(a_val + b_val)
        when '-'
          SKNum.new(a_val - b_val)
        when '*'
          SKNum.new(a_val * b_val)
        when '/'
          SKNum.new(a_val / b_val)
        when '%'
          SKNum.new(a_val % b_val)
        when '=', '>', '<'
          # Comparison operations return Church booleans
          result = case op
          when '='
            a_val == b_val
          when '>'
            a_val > b_val
          when '<'
            a_val < b_val
          end

          # Return Church boolean in SK form
          if result
            K.new  # true = K
          else
            SKApp.new(K.new, I.new)  # false = K I
          end
        else
          raise "Unknown operator #{op}"
        end
      end
    end
  end
end
