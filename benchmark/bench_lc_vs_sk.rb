#!/usr/bin/env ruby
# frozen_string_literal: true

require 'benchmark'
require_relative '../lib/bukowski/evaluator'
require_relative '../lib/bukowski/sk_translator'
require_relative '../lib/bukowski/sk_reducer'
require_relative '../lib/bukowski/cached_sk_evaluator'

include Bukowski
include Bukowski::SK

# Benchmark helpers
def bench_lc(expr, iterations = 1000)
  evaluator = Evaluator.new
  Benchmark.measure do
    iterations.times { evaluator.evaluate(expr) }
  end
end

def bench_sk_uncached(expr, iterations = 1000)
  translator = Translator.new
  reducer = Reducer.new
  Benchmark.measure do
    iterations.times do
      sk_expr = translator.translate(expr)
      reducer.reduce(sk_expr)
    end
  end
end

def bench_sk_cached(expr, iterations = 1000)
  evaluator = CachedSKEvaluator.new
  Benchmark.measure do
    iterations.times { evaluator.evaluate(expr) }
  end
end

# Test expressions
expressions = {
  "Identity function" => App.new(
    Abs.new('x', Var.new('x')),
    Num.new(5)
  ),

  "K combinator" => App.new(
    App.new(
      Abs.new('x', Abs.new('y', Var.new('x'))),
      Var.new('a')
    ),
    Var.new('b')
  ),

  "Simple arithmetic" => App.new(
    App.new(Var.new('+'), Num.new(2)),
    Num.new(3)
  ),

  "Lambda with arithmetic" => App.new(
    Abs.new('x', App.new(
      App.new(Var.new('+'), Var.new('x')),
      Num.new(3)
    )),
    Num.new(2)
  ),

  "Church true selection" => App.new(
    App.new(
      Abs.new('t', Abs.new('f', Var.new('t'))),
      Var.new('a')
    ),
    Var.new('b')
  ),

  "Church false selection" => App.new(
    App.new(
      Abs.new('t', Abs.new('f', Var.new('f'))),
      Var.new('a')
    ),
    Var.new('b')
  ),

  "If with comparison" => App.new(
    App.new(
      App.new(
        Var.new('if'),
        App.new(App.new(Var.new('='), Num.new(2)), Num.new(2))
      ),
      Num.new(10)
    ),
    Num.new(20)
  ),

  "Nested lambda" => App.new(
    App.new(
      Abs.new('x', Abs.new('y',
        App.new(App.new(Var.new('+'), Var.new('x')), Var.new('y'))
      )),
      Num.new(2)
    ),
    Num.new(3)
  ),

  "Complex expression" => App.new(
    App.new(
      Abs.new('f', App.new(
        App.new(Var.new('f'), Num.new(5)),
        Num.new(10)
      )),
      Abs.new('x', Abs.new('y',
        App.new(App.new(Var.new('*'), Var.new('x')), Var.new('y'))
      ))
    ),
    Num.new(0)  # unused
  )
}

puts "=" * 80
puts "Benchmark: Lambda Calculus vs SK Combinator Evaluation"
puts "=" * 80
puts

iterations = 10000
puts "Running #{iterations} iterations per test..."
puts

results = {}

expressions.each do |name, expr|
  puts "-" * 80
  puts name
  puts "-" * 80

  # Warm up
  Evaluator.new.evaluate(expr)
  CachedSKEvaluator.new.evaluate(expr)

  lc_time = bench_lc(expr, iterations)
  sk_uncached_time = bench_sk_uncached(expr, iterations)
  sk_cached_time = bench_sk_cached(expr, iterations)

  results[name] = {
    lc: lc_time.real,
    sk_uncached: sk_uncached_time.real,
    sk_cached: sk_cached_time.real
  }

  puts "  LC Evaluator (direct):          #{lc_time.real.round(4)}s"
  puts "  SK Uncached (translate every):  #{sk_uncached_time.real.round(4)}s"
  puts "  SK Cached (translate once):     #{sk_cached_time.real.round(4)}s"
  puts

  uncached_ratio = sk_uncached_time.real / lc_time.real
  cached_ratio = sk_cached_time.real / lc_time.real

  puts "  Uncached: #{uncached_ratio >= 1 ? "#{uncached_ratio.round(2)}x slower" : "#{(1.0/uncached_ratio).round(2)}x FASTER"}"
  puts "  Cached:   #{cached_ratio >= 1 ? "#{cached_ratio.round(2)}x slower" : "#{(1.0/cached_ratio).round(2)}x FASTER"}"
  puts
end

puts "=" * 80
puts "Summary"
puts "=" * 80
puts

avg_lc = results.values.map { |r| r[:lc] }.sum / results.size
avg_sk_uncached = results.values.map { |r| r[:sk_uncached] }.sum / results.size
avg_sk_cached = results.values.map { |r| r[:sk_cached] }.sum / results.size

puts "Average time (#{iterations} iterations):"
puts "  LC Evaluator (direct):          #{avg_lc.round(4)}s"
puts "  SK Uncached (translate every):  #{avg_sk_uncached.round(4)}s"
puts "  SK Cached (translate once):     #{avg_sk_cached.round(4)}s"
puts

uncached_ratio = avg_sk_uncached / avg_lc
cached_ratio = avg_sk_cached / avg_lc

puts "Overall performance vs LC:"
puts "  Uncached: #{uncached_ratio.round(2)}x slower (wasteful - translates same expr repeatedly)"
puts "  Cached:   #{cached_ratio >= 1 ? "#{cached_ratio.round(2)}x slower" : "#{(1.0/cached_ratio).round(2)}x FASTER"}"

puts
puts "=" * 80
puts "RECOMMENDATION"
puts "=" * 80
puts

if cached_ratio <= 1.5
  puts "✓ USE SK WITH CACHING AS DEFAULT!"
  puts
  puts "  The CachedSKEvaluator translates each unique expression once,"
  puts "  then reuses the SK form. This is only #{cached_ratio.round(2)}x slower than direct LC,"
  puts "  which is excellent for a research language."
  puts
  puts "  Benefits:"
  puts "    • Aligns with your vision (bukowski → SKI)"
  puts "    • Educational value (SK combinators)"
  puts "    • Reasonable performance"
  puts "    • Simple implementation"
else
  puts "Consider keeping LC as default for now."
  puts "SK cached is #{cached_ratio.round(2)}x slower."
end

puts
puts "=" * 80
