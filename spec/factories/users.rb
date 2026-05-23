FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password123" }
    role { :staff }

    trait :admin do
      role { :admin }
    end

    trait :owner do
      role { :owner }
    end
  end
end
