class Address < ApplicationRecord
  belongs_to :user

  validates :first_name, :last_name, :address1, :city, :state, :zipcode, :country, :phone, presence: true

  before_save :ensure_single_default
  after_destroy :promote_new_default

  def full_name
    "#{first_name} #{last_name}"
  end

  def full_address
    [ address1, city, state, zipcode, country ].compact_blank.join(", ")
  end

  private

  def ensure_single_default
    return unless is_default?
    user.addresses.where.not(id: id).update_all(is_default: false)
  end

  def promote_new_default
    return if user.addresses.exists?(is_default: true)
    user.addresses.order(:created_at).first&.update_columns(is_default: true)
  end
end
