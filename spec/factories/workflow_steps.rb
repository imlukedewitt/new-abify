# frozen_string_literal: true

FactoryBot.define do
  factory :workflow_step do
    workflow

    sequence(:name) { |n| "Step #{n}" }
    sequence(:order) { |n| n }
    config do
      {
        'liquid_templates' => {
          'name' => '1',
          'required' => 'true',
          'skip_condition' => '{{row.customer_id | present?}}',
          'method' => 'get',
          'url' => '{{base_url}}/customers/lookup.json?reference={{row.customer_reference}}',
          'success_data' => { 'customer_id' => '{{response.customer.id}}' }
        }
      }
    end
  end
end
