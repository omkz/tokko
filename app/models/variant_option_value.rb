class VariantOptionValue < ApplicationRecord
  belongs_to :product_variant
  belongs_to :product_option_value
end
