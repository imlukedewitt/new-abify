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
  attr_accessor :connection_handle

  belongs_to :workflow
  belongs_to :connection, optional: true
  has_many :step_executions, dependent: :destroy
  default_scope { order(order: :asc) }

  validates :config, presence: true
  validates :name, presence: true
  validates :order, presence: true, numericality: { only_integer: true, greater_than: 0 }
  before_validation :set_default_order, on: :create
  before_validation :resolve_connection_from_handle
  before_validation :normalize_config
  validate :validate_config
  validate :validate_connection_exists

  def step_config
    return nil if config.nil?
    return config['steps'][name] if config.key?('steps') && config['steps'].is_a?(Hash)

    config
  end

  def resolved_auth_config
    if connection.present?
      connection.credentials
    else
      workflow&.resolved_auth_config || {}
    end
  end

  private

  def set_default_order
    return if order.present?

    persisted_max = workflow.steps.maximum(:order) || 0
    unsaved_max = workflow.steps.reject(&:persisted?).reject { |s| s == self }.map(&:order).compact.max || 0
    self.order = [persisted_max, unsaved_max].max + 1
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

  def resolve_connection_from_handle
    return if connection_handle.blank? || connection_id.present?

    self.connection_id = Connection.find_by(handle: connection_handle)&.id
  end

  def validate_connection_exists
    if connection_id.present? && !Connection.exists?(connection_id)
      errors.add(:connection, 'not found')
    elsif connection_handle.present? && connection_id.blank?
      errors.add(:connection, 'not found')
    end
  end

  def normalize_config
    return unless config.is_a?(Hash) && config.dig('liquid_templates')

    templates = config['liquid_templates']
    templates['name'] = name if name.present? && templates['name'].blank?
    templates['required'] = templates['required'].in?([true, 'true'])
    templates['success_data'] = parse_json(templates['success_data'])
  end

  def parse_json(value)
    return value unless value.is_a?(String) && value.present?

    JSON.parse(value)
  rescue JSON::ParserError
    value
  end
end
