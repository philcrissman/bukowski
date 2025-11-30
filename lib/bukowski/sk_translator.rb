# frozen_string_literal: true

require_relative 'parser'
require_relative 'sk_ast'

module Bukowski
  module SK
    class Translator
      # Translate Lambda Calculus AST to SK combinator AST
      def translate(expr)
        case expr
        when Var
          # Variables become SK variables
          SKVar.new(expr.name)
        when Num
          # Numbers stay as numbers
          SKNum.new(expr.value)
        when App
          # Applications: translate both sides
          SKApp.new(translate(expr.func), translate(expr.arg))
        when Abs
          # Lambda abstraction: use bracket abstraction algorithm
          bracket_abstract(expr.param, expr.body)
        else
          raise "Unknown expression type: #{expr.class}"
        end
      end

      private

      # Bracket abstraction: T[\x.E]
      # Converts lambda abstractions to SK combinators
      def bracket_abstract(param, body)
        case body
        when Var
          if body.name == param
            # T[\x.x] = I
            I.new
          else
            # T[\x.y] = K y (where y != x)
            SKApp.new(K.new, SKVar.new(body.name))
          end
        when Num
          # T[\x.n] = K n (numbers don't contain variables)
          SKApp.new(K.new, SKNum.new(body.value))
        when Abs
          # T[\x.\y.E] = T[\x.T[\y.E]]
          # First translate the inner abstraction
          inner = bracket_abstract(body.param, body.body)
          # Then abstract over x
          bracket_abstract(param, inner)
        when App
          # T[\x.E F] = S (T[\x.E]) (T[\x.F])
          left = bracket_abstract(param, body.func)
          right = bracket_abstract(param, body.arg)

          # Optimization: if left is K E (constant), we can simplify
          # S (K E) (K F) = K (E F)
          # S (K E) I = E
          if left.is_a?(SKApp) && left.func.is_a?(K) && right.is_a?(I)
            # S (K E) I = E
            left.arg
          elsif left.is_a?(SKApp) && left.func.is_a?(K) &&
                right.is_a?(SKApp) && right.func.is_a?(K)
            # S (K E) (K F) = K (E F)
            SKApp.new(K.new, SKApp.new(left.arg, right.arg))
          elsif left.is_a?(I)
            # S I (K F) = F (because S I (K F) x = I x (K F x) = x (K F x) = ...)
            # Actually this optimization is tricky, let's skip it
            SKApp.new(SKApp.new(S.new, left), right)
          else
            # General case: S (T[\x.E]) (T[\x.F])
            SKApp.new(SKApp.new(S.new, left), right)
          end
        else
          # For SK expressions that might appear during nested translation
          if body.is_a?(SKApp) || body.is_a?(S) || body.is_a?(K) ||
             body.is_a?(I) || body.is_a?(SKVar) || body.is_a?(SKNum)
            # Already in SK form - check if param appears
            if contains_var?(body, param)
              # Need to abstract over SK expression
              # For now, treat it like an application
              # This handles the recursive case when translating nested abstractions
              abstract_sk_expr(param, body)
            else
              # param doesn't appear, so K body
              SKApp.new(K.new, body)
            end
          else
            raise "Unknown body type in bracket abstraction: #{body.class}"
          end
        end
      end

      # Check if an SK expression contains a variable
      def contains_var?(expr, var_name)
        case expr
        when SKVar
          expr.name == var_name
        when SKNum, S, K, I
          false
        when SKApp
          contains_var?(expr.func, var_name) || contains_var?(expr.arg, var_name)
        else
          false
        end
      end

      # Abstract over an SK expression (for nested abstractions)
      def abstract_sk_expr(param, expr)
        case expr
        when SKVar
          if expr.name == param
            I.new
          else
            SKApp.new(K.new, expr)
          end
        when SKNum, S, K, I
          SKApp.new(K.new, expr)
        when SKApp
          left = abstract_sk_expr(param, expr.func)
          right = abstract_sk_expr(param, expr.arg)
          SKApp.new(SKApp.new(S.new, left), right)
        else
          SKApp.new(K.new, expr)
        end
      end
    end
  end
end
