# frozen_string_literal: true

FactoryBot.define do
  factory :step_execution do
    step
    row
    status { 'pending' }
  end
end
