FactoryBot.define do
  factory :order_item do
    association :order
    association :product_variant
    quantity { 1 }
    product_name { product_variant.product.name }
    variant_options { product_variant.option_text }
    variant_sku { product_variant.sku }
    unit_price { 10_000 }
  end
end
