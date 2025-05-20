# frozen_string_literal: true

require 'liquid'

##
# StepProcessor is responsible for processing a workflow step
class StepProcessor
  attr_reader :step, :context, :config

  def initialize(step)
    raise ArgumentError, 'step is required' unless step

    @step = step
    @config = @step.config.with_indifferent_access
  end

  def self.call(step)
    new(step).execute
  end
end
