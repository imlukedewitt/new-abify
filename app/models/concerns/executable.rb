# frozen_string_literal: true

##
# This concern provides common behavior for execution models
# such as status transitions and validations
module Executable
  extend ActiveSupport::Concern

  PENDING = 'pending'
  PROCESSING = 'processing'
  SUCCESS = 'success'
  FAILED = 'failed'
  SKIPPED = 'skipped'
  COMPLETE = 'complete'

  VALID_STATUSES = [PENDING, PROCESSING, SUCCESS, FAILED, SKIPPED, COMPLETE].freeze

  included do
    validates :status, presence: true, inclusion: { in: VALID_STATUSES }

    attribute :status, :string, default: PENDING
  end

  def start!
    update!(status: PROCESSING, started_at: Time.current)
  end

  def fail!(error)
    errors = error.is_a?(Array) ? error : [error]
    update!(
      status: FAILED,
      error_messages: errors,
      completed_at: Time.current
    )
  end

  def complete!
    update!(status: COMPLETE, completed_at: Time.current)
  end

  def skip!
    update!(status: SKIPPED, completed_at: Time.current)
  end

  def pending?
    status == PENDING
  end

  def processing?
    status == PROCESSING
  end

  def failed?
    status == FAILED
  end

  # Method to be defined by subclasses if needed
  def success?
    status == SUCCESS
  end

  def skipped?
    status == SKIPPED
  end

  def complete?
    status == COMPLETE || success? || failed? || skipped?
  end
end
