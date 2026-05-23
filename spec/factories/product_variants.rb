FactoryBot.define do
  factory :product_variant do
    association :product
    sequence(:sku) { |n| "SKU-#{n.to_s.rjust(6, '0')}" }
    price { 10_000 }
    stock { 10 }
    title { "Default Title" }
  end
end
