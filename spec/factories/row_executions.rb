# frozen_string_literal: true

FactoryBot.define do
  factory :row_execution do
    row
    status { 'pending' }

    trait :processing do
      status { 'processing' }
      started_at { Time.current }
    end

    trait :complete do
      status { 'complete' }
      started_at { 1.hour.ago }
      completed_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      started_at { 1.hour.ago }
      completed_at { Time.current }
      error_messages { ['Failed to process row'] }
    end
  end
end
