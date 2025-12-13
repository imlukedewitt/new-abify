# frozen_string_literal: true

##
# WorkflowExecution model represents a specific run of a Workflow
class WorkflowExecution < ApplicationRecord
  include Executable

  belongs_to :workflow
  belongs_to :data_source
  has_many :rows, dependent: :destroy
  has_many :row_executions, through: :rows
  has_many :batches, dependent: :destroy

  validates :workflow, presence: true
  validates :data_source, presence: true

  def fail!
    update!(
      status: Executable::FAILED,
      completed_at: Time.current
    )
  end
end
