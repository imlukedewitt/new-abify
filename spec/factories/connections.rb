# frozen_string_literal: true

FactoryBot.define do
  factory :connection do
    user
    name { "My Test Connection" }
    sequence(:handle) { |n| "test_connection_#{n}" }
    credentials { { type: 'bearer', token: 'test_token_123' } }

    trait :salesforce do
      name { "Salesforce Production" }
      handle { "salesforce_prod" }
      credentials { { type: 'bearer', token: 'sf_prod_token_xyz' } }
    end

    trait :slack do
      name { "Slack Workspace" }
      handle { "slack_main" }
      credentials { { type: 'bearer', token: 'xoxb-slack-token' } }
    end

    trait :api_key_auth do
      name { "Custom API" }
      handle { "custom_api" }
      credentials { { type: 'api_key', header_name: 'X-API-KEY', value: 'custom_key_123' } }
    end

    trait :basic_auth do
      name { "Basic Auth Service" }
      handle { "basic_service" }
      credentials { { type: 'basic', username: 'testuser', password: 'testpass' } }
    end
  end
end
