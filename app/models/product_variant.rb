class ProductVariant < ApplicationRecord
  belongs_to :product

  has_many :variant_option_values,
           dependent: :destroy

  has_many :product_option_values,
           through: :variant_option_values

  validates :sku, presence: true
  validates :price, presence: true

  def option_text
    values = product_option_values.map(&:value)

    return title if values.empty?

    values.join(" / ")
  end
end
