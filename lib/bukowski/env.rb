# frozen_string_literal: true

module Bukowski
  class Env
    def initialize(parent = nil, bindings = {})
      @bindings = bindings
      @parent = parent
    end

    def get(name)
      if @bindings.key?(name)
        @bindings[name]
      elsif @parent
        @parent.get(name)
      else
        raise "Unbound variable: #{name}"
      end
    end

    def set(name, value)
      @bindings[name] = value
    end

    def extend(name, value)
      Env.new(self, { name => value })
    end
  end
end
