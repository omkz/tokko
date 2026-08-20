class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product_variant
  has_many :inventory_movements, dependent: :nullify
end
