class ProductOptionValue < ApplicationRecord
  belongs_to :product_option

  has_many :variant_option_values,
           dependent: :destroy

  has_many :product_variants,
           through: :variant_option_values

  validates :value, presence: true
end
