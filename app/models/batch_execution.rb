# frozen_string_literal: true

##
# BatchExecution represents the execution of a workflow for a batch of rows.
#
# @attr [Batch] batch The batch being processed
# @attr [Workflow] workflow The workflow being executed on the batch
# @attr [String] status The current status of this execution (pending, processing, complete, failed)
# @attr [DateTime] started_at When the execution started
# @attr [DateTime] completed_at When the execution completed (successfully or not)
class BatchExecution < ApplicationRecord
  include Executable
  belongs_to :batch
  belongs_to :workflow
  has_many :row_executions, through: :batch, source: :row_executions

  def row_statuses
    statuses = row_executions.group(:status).count

    Executable::VALID_STATUSES.each do |status|
      statuses[status] ||= 0
    end

    statuses['total'] = row_executions.count
    statuses
  end

  def all_rows_complete?
    # A batch is complete when all its row executions have a terminal status
    # (success, failed, skipped) or when there are no row executions
    return true if row_executions.empty?

    incomplete_count = row_executions.where(status: [Executable::PENDING, Executable::PROCESSING]).count
    incomplete_count.zero?
  end

  def check_completion
    return unless processing?

    if all_rows_complete?
      if row_executions.where(status: Executable::FAILED).any?
        fail!
      else
        complete!
      end
      return true
    end

    false
  end

  def fail!
    update!(
      status: Executable::FAILED,
      completed_at: Time.current
    )
  end
end
