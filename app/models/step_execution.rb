# frozen_string_literal: true

##
# StepExecution represents a single execution of a workflow step for a specific row.
#
# @attr [Step] step The step that was executed
# @attr [Row] row The row for which the step was executed
# @attr [String] status The current status of this execution (pending, processing, success, failed, skipped)
# @attr [Hash] result The result data from processing the step
# @attr [DateTime] started_at When the execution started
# @attr [DateTime] completed_at When the execution completed (successfully or not)
class StepExecution < ApplicationRecord
  belongs_to :step
  belongs_to :row

  validates :status, presence: true, inclusion: { in: %w[pending processing success failed skipped] }

  # Make result accessible
  attribute :result

  # Start the execution and mark as processing
  def start!
    update!(status: 'processing', started_at: Time.current)
  end

  # Complete the execution with success
  def succeed!(data = {})
    update!(
      status: 'success',
      result: { success: true, data: data },
      completed_at: Time.current
    )
  end

  # Complete the execution with failure
  def fail!(error)
    errors = error.is_a?(Array) ? error : [error]
    update!(
      status: 'failed',
      result: { success: false, errors: errors },
      completed_at: Time.current
    )
  end

  # Mark the execution as skipped
  def skip!
    update!(
      status: 'skipped',
      result: { success: true, skipped: true },
      completed_at: Time.current
    )
  end

  # Check if the execution was successful
  def success?
    status == 'success'
  end

  # Check if the execution failed
  def failed?
    status == 'failed'
  end

  # Check if the execution was skipped
  def skipped?
    status == 'skipped'
  end

  # Check if the execution is pending
  def pending?
    status == 'pending'
  end

  # Check if the execution is processing
  def processing?
    status == 'processing'
  end

  # Check if the execution is complete (success, failed, or skipped)
  def complete?
    success? || failed? || skipped?
  end
end
