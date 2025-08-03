# frozen_string_literal: true

FactoryBot.define do
  factory :data_source do
    sequence(:name) { |n| "Data Source #{n}" }
    type { 'DataSource' }

    # Maintain backward compatibility with old tests
    trait :csv do
      type { 'CsvData' }
    end

    trait :json do
      type { 'JsonData' }
    end

    trait :mock do
      type { 'MockData' }
    end
  end

  factory :csv_data, parent: :data_source, class: 'CsvData' do
    type { 'CsvData' }
  end

  factory :json_data, parent: :data_source, class: 'JsonData' do
    type { 'JsonData' }
  end

  factory :mock_data, parent: :data_source, class: 'MockData' do
    type { 'MockData' }
  end
end
