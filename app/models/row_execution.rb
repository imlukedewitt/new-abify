# frozen_string_literal: true

##
# RowExecution represents the execution of a workflow for a specific row.
#
# @attr [Row] row The row being processed
# @attr [String] status The current status of this execution (pending, processing, complete, failed)
# @attr [DateTime] started_at When the execution started
# @attr [DateTime] completed_at When the execution completed (successfully or not)
class RowExecution < ApplicationRecord
  include Executable
  belongs_to :row
  belongs_to :workflow_execution
  has_many :step_executions, dependent: :destroy

  def fail!
    if persisted?
      update_columns(
        status: Executable::FAILED,
        completed_at: Time.current
      )
    else
      assign_attributes(
        status: Executable::FAILED,
        completed_at: Time.current
      )
    end
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

  def merged_success_data
    step_executions
      .where(status: 'success')
      .joins(:step)
      .order('steps.position')
      .each_with_object({}) do |step_exec, merged|
        merged.merge!(step_exec.result&.dig('data') || {})
      end
  end
end
