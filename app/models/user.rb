class User < ApplicationRecord
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  has_many :inventory_movements

  enum :role, { customer: 0, staff: 1, admin: 2, owner: 3 }, default: :customer

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  generates_token_for :magic_link, expires_in: 15.minutes do
    updated_at
  end

  def dashboard_access?
    staff? || admin? || owner?
  end
end

