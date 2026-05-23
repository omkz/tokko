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

  scope :successful, -> { where(status: [:paid, :shipped, :completed]) }

  def self.total_revenue
    successful.sum(:total_price)
  end

  def self.revenue_on(date)
    where(created_at: date.beginning_of_day..date.end_of_day).successful.sum(:total_price)
  end

  validates :customer_name, :customer_email, :shipping_address, presence: true
  validates :customer_email, format: { with: URI::MailTo::EMAIL_REGEXP }
end
