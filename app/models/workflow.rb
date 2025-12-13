# frozen_string_literal: true

##
# Workflow model
# Contains a collection of Steps to be executed in sequence
class Workflow < ApplicationRecord
  belongs_to :connection, optional: true
  has_many :steps, dependent: :destroy
  has_many :workflow_executions, dependent: :restrict_with_error

  validates :name, presence: true
  validate :validate_config

  accepts_nested_attributes_for :steps

  def create_execution(data_source)
    workflow_executions.create(data_source: data_source)
  end

  def resolved_auth_config
    @resolved_auth_config ||= if connection.present?
                                connection.credentials
                              elsif config.present?
                                config.dig('connection', 'auth') || {}
                              else
                                {}
                              end
  end

  def workflow_config
    return nil if config.nil?
    return config['workflow'] if config.key?('workflow')

    config
  end

  private

  def validate_config
    return if config.nil?

    unless config.is_a?(Hash)
      errors.add(:config, 'must be a hash')
      return
    end

    validator = WorkflowConfigValidator.new(workflow_config)
    return if validator.valid?

    validator.errors.each { |error| errors.add(:config, error) }
  end
end
