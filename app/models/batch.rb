# frozen_string_literal: true

# batch model
class Batch < ApplicationRecord
  has_many :rows
  has_many :row_executions, through: :rows
end
