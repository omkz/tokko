FactoryBot.define do
  factory :order_item do
    association :order
    association :product_variant
    quantity { 1 }
    unit_price { 10_000 }
  end
end
