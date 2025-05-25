# frozen_string_literal: true

require 'liquid'
require_relative 'liquid_processor'

##
# StepProcessor is responsible for processing a workflow step
class StepProcessor
  attr_reader :step, :row, :config

  def initialize(step, row)
    raise ArgumentError, 'step is required' unless step
    raise ArgumentError, 'row is required' unless row

    @step = step
    @row = row
    @config = @step.config.with_indifferent_access
  end

  def self.call(step, row)
    new(step, row).call
  end

  def call
    # .
  end

  def should_skip?
    skip_condition = @config['skip_condition']
    return false unless skip_condition

    processor = LiquidProcessor.new(skip_condition, build_context)
    processor.process_as_boolean
  end

  private

  def build_context
    {
      row: @row.data
    }
  end
end
