# frozen_string_literal: true

FactoryBot.define do
  factory :row do
    workflow_execution
    data_source
    status { 'pending' }
    sequence(:source_index) { |n| n }
    data { { first_name: "John", last_name: "Doe", email: "john.doe@example.com", organization: "Acme Corp" } }

    trait :with_batch do
      association :batch
    end

    trait :with_custom_data do
      transient do
        custom_fields { {} }
      end

      data do
        { first_name: "John", last_name: "Doe", email: "john.doe@example.com" }.merge(custom_fields)
      end
    end

    trait :processed do
      status { 'processed' }
    end

    trait :failed do
      status { 'failed' }
    end

    trait :skipped do
      status { 'skipped' }
    end
  end
end
