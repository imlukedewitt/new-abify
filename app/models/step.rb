# frozen_string_literal: true

##
# Represents a step in a workflow sequence.
# Each step has a specific order, configuration, and name.
#
# @attr_reader [String] name The name of the workflow step
# @attr_reader [Hash] config The configuration settings for this step
# @attr_reader [Integer] order The position of this step in the workflow sequence
#
# @attr [Workflow] workflow The workflow this step belongs to
class Step < ApplicationRecord
  belongs_to :workflow
  has_many :step_executions, dependent: :destroy
  default_scope { order(order: :asc) }

  validates :config, presence: true
  validates :name, presence: true
  validates :order, presence: true, numericality: { only_integer: true, greater_than: 0 }
  before_validation :set_default_order, on: :create
  validate :validate_config

  def process(row)
    StepProcessor.call(self, row)
  end

  def step_config
    return nil if config.nil?
    return config['steps'][name] if config.key?('steps') && config['steps'].is_a?(Hash)

    config
  end

  private

  def set_default_order
    return if order.present?

    max_order = workflow.steps.maximum(:order) || 0
    self.order = max_order + 1
  end

  def validate_config
    if config.nil?
      errors.add(:config, "can't be blank")
      return
    end

    unless config.is_a?(Hash)
      errors.add(:config, 'must be a hash')
      return
    end

    validator = StepConfigValidator.new(step_config)
    return if validator.valid?

    validator.errors.each { |error| errors.add(:config, error) }
  end
end
