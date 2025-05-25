# frozen_string_literal: true

FactoryBot.define do
  factory :row do
    workflow_execution
    data_source
    data { { first_name: "John", last_name: "Doe", email: "john.doe@example.com", organization: "Acme Corp" } }
  end
end
