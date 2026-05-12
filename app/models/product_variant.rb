class ProductVariant < ApplicationRecord
  belongs_to :product

  has_many :variant_option_values,
           dependent: :destroy

  has_many :product_option_values,
           through: :variant_option_values

  scope :search_by_product_name, ->(query) {
    return all if query.blank?
    where("products.name ILIKE ?", "%#{query}%")
  }

  validates :sku, presence: true
  validates :price, presence: true

  def option_text
    values = product_option_values.map(&:value)

    return title if values.empty?

    values.join(" / ")
  end
end
