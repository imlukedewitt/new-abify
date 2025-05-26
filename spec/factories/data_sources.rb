# frozen_string_literal: true

FactoryBot.define do
  factory :data_source do
    sequence(:name) { |n| "Data Source #{n}" }
    type { 'CsvData' }

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
end
