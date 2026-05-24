class User < ApplicationRecord
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  has_many :inventory_movements
  has_many :wishlist_items, dependent: :destroy
  has_many :wishlisted_products, through: :wishlist_items, source: :product

  enum :role, { customer: 0, staff: 1, admin: 2, owner: 3 }, default: :customer

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  generates_token_for :magic_link, expires_in: 15.minutes do
    updated_at
  end

  def full_name
    [ first_name, last_name ].compact_blank.join(" ").presence || email_address.split("@").first
  end

  def dashboard_access?
    staff? || admin? || owner?
  end
end
