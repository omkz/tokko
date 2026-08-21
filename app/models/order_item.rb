class OrderItem < ApplicationRecord
  attr_readonly :product_name, :variant_options, :variant_sku, :unit_price

  belongs_to :order
  belongs_to :product_variant
  has_many :inventory_movements, dependent: :nullify
end
