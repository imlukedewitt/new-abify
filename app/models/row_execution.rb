# frozen_string_literal: true

##
# RowExecution represents the execution of a workflow for a specific row.
#
# @attr [Row] row The row being processed
# @attr [String] status The current status of this execution (pending, processing, complete, failed)
# @attr [Array] responses Responses from step executions (stored as JSON array)
# @attr [Array] error_messages Any error messages that occurred during processing (stored as JSON array)
# @attr [DateTime] started_at When the execution started
# @attr [DateTime] completed_at When the execution completed (successfully or not)
class RowExecution < ApplicationRecord
  include Executable
  belongs_to :row
  has_many :step_executions, through: :row

  def fail!(error_messages)
    error_list = error_messages.is_a?(Array) ? error_messages : [error_messages]
    update!(
      status: Executable::FAILED,
      error_messages: error_list,
      completed_at: Time.current
    )
  end

  # TODO: this is AI. Need to add actual functions to load row responses/errors etc
  def step_statuses
    statuses = step_executions.group(:status).count

    Executable::VALID_STATUSES.each do |status|
      statuses[status] ||= 0
    end

    statuses['total'] = step_executions.count
    statuses
  end
end
