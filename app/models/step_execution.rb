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
  include Executable
  belongs_to :step
  belongs_to :row

  attribute :result

  def succeed!(data = {})
    update!(
      status: Executable::SUCCESS,
      result: { success: true, data: data },
      completed_at: Time.current
    )
  end

  def fail!(error)
    errors = error.is_a?(Array) ? error : [error]
    update!(
      status: Executable::FAILED,
      result: { success: false, errors: errors },
      completed_at: Time.current
    )
  end

  def skip!
    update!(
      status: Executable::SKIPPED,
      result: { success: true, skipped: true },
      completed_at: Time.current
    )
  end
end
