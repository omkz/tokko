FactoryBot.define do
  factory :cart do
    expires_at { 30.days.from_now }

    trait :for_user do
      association :user
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
