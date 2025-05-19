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
class WorkflowStep < ApplicationRecord
  belongs_to :workflow
  default_scope { order(order: :asc) }

  validates :config, presence: true
  validates :name, presence: true
  validates :order, presence: true, numericality: { only_integer: true, greater_than: 0 }

  validate :validate_config

  CONFIG_REQUIRED_KEYS = %w[
    name
    url
  ].freeze
  CONFIG_OPTIONAL_KEYS = %w[
    required
    method
    body
    params
    skip_condition
    success_data
  ].freeze

  private

  def validate_config
    unless config.is_a?(Hash)
      errors.add(:config, 'must be a hash')
      return
    end

    unless config.key?('liquid_templates') && config['liquid_templates'].is_a?(Hash)
      errors.add(:config, 'must include liquid_templates hash')
      return
    end

    validate_required_keys
    validate_no_extra_keys
  end

  def validate_required_keys
    CONFIG_REQUIRED_KEYS.each do |key|
      errors.add(:config, "must include #{key}") unless config['liquid_templates'].key?(key)
    end
  end

  def validate_no_extra_keys
    extra_keys = config['liquid_templates'].keys - (CONFIG_REQUIRED_KEYS + CONFIG_OPTIONAL_KEYS)
    extra_keys.each { |key| errors.add(:config, "unexpected key in liquid_templates: #{key}") }
  end
end
