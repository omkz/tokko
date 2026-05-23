FactoryBot.define do
  factory :inventory_movement do
    association :product_variant
    quantity { 10 }
    reason { :restock }

    trait :sale do
      quantity { -1 }
      reason { :sale }
    end

    trait :adjustment do
      reason { :adjustment }
    end

    trait :with_user do
      association :user
    end
  end
end
