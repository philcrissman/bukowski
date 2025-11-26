# frozen_string_literal: true

require_relative "bukowski/version"
require_relative "bukowski/tokenizer"
require_relative "bukowski/parser"
require_relative "bukowski/evaluator"
require_relative "bukowski/repl"

module Bukowski

  if __FILE__ == $PROGRAM_NAME
    repl = Bukowski::REPL.new
    repl.run
  end

  class Error < StandardError; end
  # Your code goes here...
end
