module Bukowski
  class Evaluator
    PartialOp = Struct.new(:op, :arg) do
      def to_s
        "(#{op} #{arg} ...)"
      end
    end

    # Helper to detect if an expression is a Church boolean
    def self.church_boolean?(expr)
      return nil unless expr.is_a?(Abs)

      # Check if it's λt.λf.t (true)
      if expr.param == 't' &&
         expr.body.is_a?(Abs) &&
         expr.body.param == 'f' &&
         expr.body.body.is_a?(Var) &&
         expr.body.body.name == 't'
        return :true
      end

      # Check if it's λt.λf.f (false)
      if expr.param == 't' &&
         expr.body.is_a?(Abs) &&
         expr.body.param == 'f' &&
         expr.body.body.is_a?(Var) &&
         expr.body.body.name == 'f'
        return :false
      end

      nil
    end

    def evaluate(expr)
      case expr
      when Var
        # Church booleans
        case expr.name
        when 'true'
          # λt.λf.t - returns first argument
          Abs.new('t', Abs.new('f', Var.new('t')))
        when 'false'
          # λt.λf.f - returns second argument
          Abs.new('t', Abs.new('f', Var.new('f')))
        when 'if'
          # if is just the identity function for Church booleans
          # (if cond then else) = (cond then else)
          Abs.new('x', Var.new('x'))
        else
          expr
        end
      when Num
        expr
      when Str
        expr
      when Abs
        expr
      when App
        func = evaluate(expr.func)
        # LAZY: Don't evaluate arg yet!

        case func
        when Var
          if ['+', '-', '*', '/', '%', '=', '<', '>'].include?(func.name)
            # For primitives, we need to evaluate the arg
            PartialOp.new(func.name, evaluate(expr.arg))
          else
            # Unknown variable applied to something - evaluate arg
            App.new(func, evaluate(expr.arg))
          end
        when PartialOp
          # For primitives, evaluate the second arg
          apply_operation(func.op, func.arg, evaluate(expr.arg))
        when Abs
          # LAZY: Substitute UNEVALUATED argument (call-by-name)
          reduced = substitute(func.body, func.param, expr.arg)
          evaluate(reduced)
        else
          App.new(func, evaluate(expr.arg))
        end
      end
    end

    private

    def substitute(body, param, arg)
      case body
      when Var
        body.name == param ? arg : body
      when Num
        # Numbers don't contain variables, return unchanged
        body
      when Str
        # Strings don't contain variables, return unchanged
        body
      when Abs
        if body.param == param
          body
        else
          Abs.new(body.param, substitute(body.body, param, arg))
        end
      when App
        App.new(
          substitute(body.func, param, arg),
          substitute(body.arg, param, arg)
        )
      else
        # Shouldn't happen, but return unchanged for safety
        body
      end
    end

    def apply_operation(op, a, b)
      a_val = a.is_a?(Num) ? a.value : a
      b_val = b.is_a?(Num) ? b.value : b

      case op
      when '+'
        Num.new(a_val + b_val)
      when '-'
        Num.new(a_val - b_val)
      when '*'
        Num.new(a_val * b_val)
      when '/'
        Num.new(a_val / b_val)
      when '%'
        Num.new(a_val % b_val)
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
        # Return Church boolean
        if result
          Abs.new('t', Abs.new('f', Var.new('t')))  # true
        else
          Abs.new('t', Abs.new('f', Var.new('f')))  # false
        end
      else
        raise "Unknown operator #{op}"
      end
    end
  end
end
