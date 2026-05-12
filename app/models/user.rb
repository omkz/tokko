class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :orders, dependent: :nullify
  
  enum :role, { staff: 0, admin: 1, owner: 2 }, default: :staff

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
