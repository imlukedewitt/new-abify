# frozen_string_literal: true

FactoryBot.define do
  factory :data_source do
    sequence(:name) { |n| "Data Source #{n}" }
    type { 'DataSource' }

    # Maintain backward compatibility with old tests
    trait :csv do
      type { 'DataSources::Csv' }
    end

    trait :json do
      type { 'DataSources::Json' }
    end

    trait :mock do
      type { 'MockData' }
    end
  end

  factory :csv, parent: :data_source, class: 'DataSources::Csv' do
    type { 'DataSources::Csv' }
  end

  factory :json, parent: :data_source, class: 'DataSources::Json' do
    type { 'DataSources::Json' }
  end

  factory :mock_data, parent: :data_source, class: 'MockData' do
    type { 'MockData' }
  end
end
