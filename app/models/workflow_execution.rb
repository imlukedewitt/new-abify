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

  def fail!(message = nil)
    update!(
      status: Executable::FAILED,
      completed_at: Time.current,
      error_message: message
    )
  end
end
