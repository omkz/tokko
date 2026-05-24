class Coupon < ApplicationRecord
  has_many :orders

  enum :discount_type, { percentage: "percentage", fixed: "fixed" }

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :discount_type, presence: true
  validates :value, presence: true, numericality: { greater_than: 0 }
  validates :value, numericality: { less_than_or_equal_to: 100 }, if: :percentage?

  before_save { self.code = code.upcase.strip }

  def discount_for(subtotal)
    return 0 if minimum_order.present? && subtotal < minimum_order

    if percentage?
      (subtotal * value / 100).round(2)
    else
      [ value, subtotal ].min
    end
  end

  def valid_for_use?
    return false unless active?
    return false if expires_at.present? && expires_at < Time.current
    return false if usage_limit.present? && orders.size >= usage_limit
    true
  end

  def usage_count
    orders.size
  end
end
