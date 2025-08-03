# frozen_string_literal: true

##
# Row model
class Row < ApplicationRecord
  belongs_to :workflow_execution
  belongs_to :data_source
  belongs_to :batch, optional: true
  has_many :step_executions, dependent: :destroy
  has_many :row_executions, dependent: :destroy

  after_initialize :set_original_data, if: :new_record?

  private

  def set_original_data
    self.original_data = data.deep_dup if data.present?
  end
end
