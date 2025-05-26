# frozen_string_literal: true

FactoryBot.define do
  factory :workflow_execution do
    workflow
    data_source
    status { 'pending' }

    trait :with_rows do
      transient do
        row_count { 3 }
      end

      after(:create) do |execution, evaluator|
        create_list(:row, evaluator.row_count, workflow_execution: execution, data_source: execution.data_source)
      end
    end

    trait :with_batches do
      after(:create) do |execution|
        batch = create(:batch)
        create_list(:row, 3, workflow_execution: execution, data_source: execution.data_source, batch: batch)
      end
    end

    factory :complete_workflow_execution, traits: [:with_rows]
  end
end
