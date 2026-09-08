class User < ApplicationRecord
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  has_many :inventory_movements
  has_many :wishlist_items, dependent: :destroy
  has_many :wishlisted_products, through: :wishlist_items, source: :product
  has_many :addresses, dependent: :destroy

  enum :role, { customer: 0, staff: 1, admin: 2, owner: 3 }, default: :customer

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :password, presence: true, confirmation: true, on: :password_reset
  validates :password_confirmation, presence: true, on: :password_reset
  validate :password_within_bcrypt_limit, on: :password_reset

  generates_token_for :magic_link, expires_in: 15.minutes do
    updated_at
  end

  def full_name
    [ first_name, last_name ].compact_blank.join(" ").presence || email_address.split("@").first
  end

  def dashboard_access?
    staff? || admin? || owner?
  end

  private
    def password_within_bcrypt_limit
      return unless password.present? && password.bytesize > ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED

      errors.add(:password, :password_too_long)
    end
end
