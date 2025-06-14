# frozen_string_literal: true

# batch model
class Batch < ApplicationRecord
  PROCESSING_MODES = %w[sequential parallel].freeze

  belongs_to :workflow_execution, optional: true
  has_many :rows
  has_many :row_executions, through: :rows

  after_initialize :set_default_processing_mode, if: :new_record?

  validates :processing_mode,
            inclusion: { in: PROCESSING_MODES, message: "%<value>s is not a valid processing mode" }

  private

  def set_default_processing_mode
    self.processing_mode ||= "sequential"
  end
end
