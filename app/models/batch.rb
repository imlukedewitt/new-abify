# frozen_string_literal: true

# batch model
class Batch < ApplicationRecord
  has_many :rows
end
