# frozen_string_literal: true

##
# Row model
class Row < ApplicationRecord
  belongs_to :data_source
  belongs_to :batch, optional: true
  has_many :step_executions, dependent: :destroy
  has_many :row_executions, dependent: :destroy
end
