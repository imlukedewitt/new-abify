FactoryBot.define do
  factory :batch_execution do
    association :batch
    association :workflow
    status { Executable::PENDING }
    started_at { nil }
    completed_at { nil }

    trait :processing do
      status { Executable::PROCESSING }
      started_at { Time.current }
    end

    trait :complete do
      status { Executable::COMPLETE }
      started_at { Time.current }
      completed_at { Time.current }
    end

    trait :failed do
      status { Executable::FAILED }
      started_at { Time.current }
      completed_at { Time.current }
    end
  end
end
