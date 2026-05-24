FactoryBot.define do
  factory :cart_item do
    association :cart
    association :product_variant
    quantity { 1 }
  end
end
