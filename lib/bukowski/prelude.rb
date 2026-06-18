# frozen_string_literal: true

module Bukowski
  module Prelude
    PATH = File.join(__dir__, 'prelude.bk')

    def self.source
      @source ||= File.read(PATH)
    end

    def self.load_defines(evaluator)
      defines = []
      evaluator.evaluate_program(source, defines: defines)
      defines
    end
  end
end
