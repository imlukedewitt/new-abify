# frozen_string_literal: true

##
# WorkflowExecution model represents a specific run of a Workflow
class WorkflowExecution < ApplicationRecord
  include Executable

  belongs_to :workflow
  belongs_to :data_source
  has_many :row_executions, dependent: :destroy
  has_many :rows, through: :row_executions
  has_many :batches, dependent: :destroy

  validates :workflow, presence: true
  validates :data_source, presence: true
  validate :validate_connection_mappings

  def fail!(message = nil)
    if persisted?
      update_columns(
        status: Executable::FAILED,
        completed_at: Time.current,
        error_message: message
      )
    else
      assign_attributes(
        status: Executable::FAILED,
        completed_at: Time.current,
        error_message: message
      )
    end
  end

  private

  def validate_connection_mappings
    return if workflow.nil?

    # Use Resolver to check for missing slots and ownership
    resolver = ConnectionSlot::Resolver.new(
      workflow: workflow,
      connection_mappings: connection_mappings || {}
    )
    resolution = resolver.call

    resolution[:errors].each { |error| errors.add(:connection_mappings, error) } if resolution[:errors].any?

    # Also check structure of what is there
    return if connection_mappings.nil?

    validator = ConnectionMappingsValidator.new(connection_mappings)
    return if validator.valid?

    validator.errors.each { |error| errors.add(:connection_mappings, error) }
  end
end
