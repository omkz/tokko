FactoryBot.define do
  factory :coupon do
    sequence(:code) { |n| "SAVE#{n}" }
    discount_type { :percentage }
    value { 10 }
    active { true }
  end
end
