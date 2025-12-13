# frozen_string_literal: true

FactoryBot.define do
  factory :workflow do
    sequence(:name) { |n| "Workflow #{n}" }
    config do
      {
        'workflow' => {
          'liquid_templates' => {
            'group_by' => nil,
            'sort_by' => nil
          },
          'connection' => {
            'subdomain' => 'acme',
            'domain' => 'application.com'
          }
        }
      }
    end

    trait :with_handle do
      sequence(:handle) { |n| "workflow-#{n}" }
    end

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
