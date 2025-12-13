# frozen_string_literal: true

FactoryBot.define do
  factory :step_execution do
    step
    row
    row_execution
    status { 'pending' }
  end
end
