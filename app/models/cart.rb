class Cart < ApplicationRecord
  belongs_to :user, optional: true
  has_many :cart_items, dependent: :destroy
  has_many :product_variants, through: :cart_items

  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  def merge_from(other_cart)
    return if other_cart.nil? || other_cart.id == id

    other_cart.cart_items.each do |item|
      existing = cart_items.find_by(product_variant_id: item.product_variant_id)
      if existing
        existing.update!(quantity: existing.quantity + item.quantity)
      else
        cart_items.create!(product_variant_id: item.product_variant_id, quantity: item.quantity)
      end
    end
    other_cart.destroy
  end

  def total_price
    cart_items.includes(:product_variant).sum { |item| item.product_variant.price * item.quantity }
  end

  def item_count
    cart_items.sum(:quantity)
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end
end
