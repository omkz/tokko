class ProductFilterOption < ApplicationRecord
  belongs_to :product
  belongs_to :filter_option

  validates :filter_option_id, uniqueness: { scope: :product_id }
end
