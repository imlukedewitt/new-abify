# frozen_string_literal: true

FactoryBot.define do
  factory :workflow_step do
    workflow

    sequence(:name) { |n| "Step #{n}" }
    sequence(:order) { |n| n }
    config do
      {
        'name_template' => '1',
        'required_template' => 'true',
        'skip_condition_template' => '{{row.customer_id | present?}}',
        'method_template' => 'get',
        'url_template' => '{{base_url}}/customers/lookup.json?reference={{row.customer_reference}}',
        'success_data_template' => { 'customer_id' => '{{response}}' }
      }
    end
  end
end
