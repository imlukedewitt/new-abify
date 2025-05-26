# frozen_string_literal: true

FactoryBot.define do
  factory :batch do
    transient do
      row_count { 0 }
      workflow_execution { nil }
    end

    trait :with_rows do
      transient do
        row_count { 3 }
      end

      after(:create) do |batch, evaluator|
        if evaluator.workflow_execution
          create_list(:row, evaluator.row_count,
                      batch: batch,
                      workflow_execution: evaluator.workflow_execution,
                      data_source: evaluator.workflow_execution.data_source)
        else
          wf_execution = create(:workflow_execution)
          create_list(:row, evaluator.row_count,
                      batch: batch,
                      workflow_execution: wf_execution,
                      data_source: wf_execution.data_source)
        end
      end
    end
  end
end
