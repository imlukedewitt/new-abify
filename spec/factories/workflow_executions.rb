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

    trait :with_connection_mappings do
      workflow do
        association :workflow, connection_slots: [{ 'handle' => 'primary_db', 'description' => 'Primary Database' }]
      end
      connection_mappings do
        conn = create(:connection, user: Current.user || User.last || create(:user), name: 'Primary Database')
        {
          'primary_db' => {
            'connection_id' => conn.id.to_s,
            'connection_name' => conn.name,
            'connection_handle' => conn.handle
          }
        }
      end
    end

    trait :complete do
      status { 'complete' }
      started_at { 1.hour.ago }
      completed_at { Time.current }
    end

    factory :complete_workflow_execution, traits: [:with_rows]
  end
end
