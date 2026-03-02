# frozen_string_literal: true

##
# Represents a step in a workflow sequence.
# Each step has a specific order, configuration, and name.
#
# @attr_reader [String] name The name of the workflow step
# @attr_reader [Hash] config The configuration settings for this step
# @attr_reader [Integer] position The position of this step in the workflow sequence
#
# @attr [Workflow] workflow The workflow this step belongs to
class Step < ApplicationRecord
  belongs_to :workflow
  has_many :step_executions, dependent: :destroy
  default_scope { order(position: :asc) }

  validates :config, presence: true
  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  before_validation :set_default_position, on: :create
  before_validation :normalize_config
  validate :validate_config

  def step_config
    return nil if config.nil?
    return config['steps'][name] if config.key?('steps') && config['steps'].is_a?(Hash)

    config
  end

  private

  def set_default_position
    return if position.present?

    persisted_max = workflow.steps.maximum(:position) || 0
    unsaved_max = workflow.steps.reject(&:persisted?).reject { |s| s == self }.map(&:position).compact.max || 0
    self.position = [persisted_max, unsaved_max].max + 1
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

  def normalize_config
    return unless (templates = liquid_templates)

    templates['name'] = name if name.present? && templates['name'].blank?
    templates['required'] = normalize_required(templates['required'])
    templates['success_data'] = parse_json(templates['success_data'])
  end

  def normalize_required(value)
    return value unless value.is_a?(String) && !value.include?('{{')

    value == 'true'
  end

  def liquid_templates
    config['liquid_templates'] if config.is_a?(Hash)
  end

  def parse_json(value)
    return value unless value.is_a?(String) && value.present?

    JSON.parse(value)
  rescue JSON::ParserError
    value
  end
end
