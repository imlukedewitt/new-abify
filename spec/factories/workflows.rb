# frozen_string_literal: true

FactoryBot.define do
  factory :workflow do
    sequence(:name) { |n| "Workflow #{n}" }
    # Default configuration, can be overridden
    config { { 'batch' => { 'group_by' => nil, 'sort_by' => nil } } }

    trait :with_step do
      after(:create) do |workflow|
        create(:step, workflow: workflow, order: 1)
      end
    end

    trait :with_steps do
      after(:create) do |workflow|
        create(:step, workflow: workflow, order: 1, name: "First Step")
        create(:step, workflow: workflow, order: 2, name: "Second Step")
        create(:step, workflow: workflow, order: 3, name: "Third Step")
      end
    end
  end
end
