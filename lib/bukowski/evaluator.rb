# frozen_string_literal: true

require_relative 'tokenizer'
require_relative 'parser'
require_relative 'env'
require_relative 'values'

module Bukowski
  class Evaluator
    include Val

    def initialize
      @global_env = default_env
    end

    def evaluate(expr, env = @global_env)
      case expr
      when Num
        VNum.new(expr.value)
      when Str
        VStr.new(expr.value)
      when Var
        env.get(expr.name)
      when Abs
        VClosure.new(expr.param, expr.body, env)
      when App
        if (parts = extract_if(expr))
          eval_if(parts, env)
        else
          func = evaluate(expr.func, env)
          arg = evaluate(expr.arg, env)
          apply_value(func, arg)
        end
      else
        raise "Unknown expression type: #{expr.class}"
      end
    end

    def evaluate_source(source)
      tokens = Tokenizer.new(source).tokenize
      ast = Parser.new(tokens).parse
      evaluate(ast)
    end

    def evaluate_program(source, defines: [])
      results = []

      each_statement(source) do |stmt|
        tokens = Tokenizer.new(stmt).tokenize
        ast = Parser.new(tokens).parse

        if ast.is_a?(Define)
          val = evaluate(ast.value)
          @global_env.set(ast.name, val)
          defines << ast
        else
          results << evaluate(ast)
        end
      end

      results
    end

    def apply_value(func, arg)
      case func
      when VClosure
        new_env = func.env.extend(func.param, arg)
        evaluate(func.body, new_env)
      when VBuiltin
        func.impl.call(arg)
      when VYCombinator
        partial = apply_value(func.f, func)
        apply_value(partial, arg)
      else
        raise "Cannot apply #{func.class}: #{func}"
      end
    end

    private

    # Detect ((if cond) then) else in the AST for lazy branching
    def extract_if(expr)
      return nil unless expr.is_a?(App) &&
                        expr.func.is_a?(App) &&
                        expr.func.func.is_a?(App) &&
                        expr.func.func.func.is_a?(Var) &&
                        expr.func.func.func.name == 'if'
      [expr.func.func.arg, expr.func.arg, expr.arg]
    end

    def eval_if(parts, env)
      cond_ast, then_ast, else_ast = parts
      cond_val = evaluate(cond_ast, env)
      unless cond_val.is_a?(VBool)
        raise "if: condition must be a boolean, got #{cond_val.class}"
      end
      if cond_val.value
        evaluate(then_ast, env)
      else
        evaluate(else_ast, env)
      end
    end

    def default_env
      env = Env.new

      env.set('true', VBool.new(true))
      env.set('false', VBool.new(false))

      # if as a strict fallback for partial application
      env.set('if', VBuiltin.new('if', ->(cond) {
        VBuiltin.new('if_1', ->(then_val) {
          VBuiltin.new('if_2', ->(else_val) {
            raise "if: condition must be a boolean" unless cond.is_a?(VBool)
            cond.value ? then_val : else_val
          })
        })
      }))

      ['+', '-', '*', '/', '%'].each { |op| env.set(op, make_arith_op(op)) }
      ['=', '<', '>'].each { |op| env.set(op, make_comparison_op(op)) }

      env.set('nil', VNil.new)
      env.set('cons', VBuiltin.new('cons', ->(head) {
        VBuiltin.new('cons_1', ->(tail) { VCons.new(head, tail) })
      }))
      env.set('head', make_unary_list_op('head') { |lst| lst.head })
      env.set('car', env.get('head'))
      env.set('tail', make_unary_list_op('tail') { |lst| lst.tail })
      env.set('cdr', env.get('tail'))

      env.set('isnil', VBuiltin.new('isnil', ->(val) {
        case val
        when VNil then VBool.new(true)
        when VCons then VBool.new(false)
        else raise "isnil: not a list"
        end
      }))

      env.set('length', VBuiltin.new('length', ->(val) {
        case val
        when VStr
          VNum.new(val.value.length)
        when VNil
          VNum.new(0)
        when VCons
          count = 0
          node = val
          while node.is_a?(VCons)
            count += 1
            node = node.tail
          end
          VNum.new(count)
        else
          raise "length: not a sequence"
        end
      }))

      env.set('Y', VBuiltin.new('Y', ->(f) { VYCombinator.new(f) }))

      env.set('map', VBuiltin.new('map', ->(f) {
        VBuiltin.new('map_1', ->(lst) { eval_map(f, lst) })
      }))

      env.set('fold', VBuiltin.new('fold', ->(f) {
        VBuiltin.new('fold_1', ->(init) {
          VBuiltin.new('fold_2', ->(lst) { eval_fold(f, init, lst) })
        })
      }))

      env
    end

    def make_arith_op(op)
      VBuiltin.new(op, ->(a) {
        VBuiltin.new("#{op}_partial", ->(b) {
          if op == '+'
            if a.is_a?(VStr) && b.is_a?(VStr)
              VStr.new(a.value + b.value)
            elsif a.is_a?(VNum) && b.is_a?(VNum)
              VNum.new(a.value + b.value)
            else
              raise "#{op}: type mismatch (#{a.class} and #{b.class})"
            end
          else
            raise "#{op}: expected numbers" unless a.is_a?(VNum) && b.is_a?(VNum)
            VNum.new(a.value.send(op.to_sym, b.value))
          end
        })
      })
    end

    def make_comparison_op(op)
      VBuiltin.new(op, ->(a) {
        VBuiltin.new("#{op}_partial", ->(b) {
          result = if op == '='
            a.class == b.class && extract_value(a) == extract_value(b)
          else
            unless (a.is_a?(VNum) && b.is_a?(VNum)) || (a.is_a?(VStr) && b.is_a?(VStr))
              raise "#{op}: type mismatch (#{a.class} and #{b.class})"
            end
            extract_value(a).send(op == '<' ? :< : :>, extract_value(b))
          end
          VBool.new(result)
        })
      })
    end

    def extract_value(val)
      case val
      when VNum, VStr, VBool then val.value
      else val
      end
    end

    def make_unary_list_op(name)
      VBuiltin.new(name, ->(lst) {
        raise "#{name}: empty list" unless lst.is_a?(VCons)
        yield lst
      })
    end

    def eval_map(f, lst)
      return VNil.new if lst.is_a?(VNil)
      raise "map: not a list" unless lst.is_a?(VCons)
      head = apply_value(f, lst.head)
      tail = eval_map(f, lst.tail)
      VCons.new(head, tail)
    end

    def eval_fold(f, init, lst)
      return init if lst.is_a?(VNil)
      raise "fold: not a list" unless lst.is_a?(VCons)
      rest = eval_fold(f, init, lst.tail)
      apply_value(apply_value(f, lst.head), rest)
    end

    def each_statement(source)
      buffer = ""
      depth = 0

      source.each_line do |line|
        line.each_char do |c|
          depth += 1 if c == '(' || c == '{'
          depth -= 1 if c == ')' || c == '}'
        end
        buffer += line

        if depth <= 0
          stripped = buffer.strip
          unless stripped.empty? || stripped.start_with?('#')
            yield buffer
          end
          buffer = ""
          depth = 0
        end
      end

      unless buffer.strip.empty?
        yield buffer
      end
    end
  end
end
