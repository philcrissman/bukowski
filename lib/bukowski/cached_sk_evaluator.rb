# frozen_string_literal: true

require_relative 'sk_translator'
require_relative 'sk_reducer'

module Bukowski
  # Evaluator that translates LC to SK with caching
  class CachedSKEvaluator
    def initialize
      @translator = SK::Translator.new
      @reducer = SK::Reducer.new
      @translation_cache = {}
    end

    def evaluate(expr)
      # Cache translations based on the expression object
      # In a real implementation, you might want a more sophisticated cache key
      sk_expr = @translation_cache[expr] ||= @translator.translate(expr)
      @reducer.reduce(sk_expr)
    end

    def cache_size
      @translation_cache.size
    end

    def clear_cache
      @translation_cache.clear
    end
  end
end
