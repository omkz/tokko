class Order < ApplicationRecord
  has_many :order_items, dependent: :destroy
  has_many :product_variants, through: :order_items

  enum :status, {
    pending: 0,
    paid: 1,
    shipped: 2,
    completed: 3,
    cancelled: 4
  }, default: :pending

  validates :customer_name, :customer_email, presence: true
end
