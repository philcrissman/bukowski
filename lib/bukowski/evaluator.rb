module Bukowski
  class Evaluator

    def evaluate(expr)
      case expr
      when Var
        expr
      when Abs
        expr
      when App
        func = evaluate(expr.func)
        if func.is_a?(Abs)
          reduced = substitute(func.body, func.param, expr.arg)
          evaluate(reduced)
        else
          arg = evaluate(expr.arg)
          App.new(func, arg)
        end
      end
    end

    private

    def substitute(body, param, arg)
      case body
      when Var
        body.name == param ? arg : body
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
      end
    end
  end
end
